import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isLoading = false;
  String _lastBackupDate = 'Never';
  String _lastBackupSize = '';
  String _lastAutoBackupDate = 'Never';
  bool _isLastBackupEncrypted = false;
  
  bool _encryptBackup = false;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastBackupDate = prefs.getString('last_backup_date') ?? 'Never';
      _lastBackupSize = prefs.getString('last_backup_size') ?? '';
      _lastAutoBackupDate = prefs.getString('last_auto_backup_display') ?? 'Never';
      _isLastBackupEncrypted = prefs.getBool('last_backup_encrypted') ?? false;
    });
  }

  Future<void> _saveMetadata(int sizeBytes, bool encrypted) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = DateFormat('MMM dd, yyyy · HH:mm').format(DateTime.now());
    
    final sizeKb = sizeBytes / 1024;
    String sizeStr;
    if (sizeKb > 1024) {
      sizeStr = '${(sizeKb / 1024).toStringAsFixed(1)} MB';
    } else {
      sizeStr = '${sizeKb.toStringAsFixed(0)} KB';
    }

    await prefs.setString('last_backup_date', dateStr);
    await prefs.setString('last_backup_size', sizeStr);
    await prefs.setBool('last_backup_encrypted', encrypted);
    
    setState(() {
      _lastBackupDate = dateStr;
      _lastBackupSize = sizeStr;
      _isLastBackupEncrypted = encrypted;
    });
  }

  Future<void> _handleCreateBackup() async {
    if (_encryptBackup && _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a password for encryption'), backgroundColor: context.colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      
      final zipPath = await backupService.createBackup(
        password: _encryptBackup ? _passwordController.text : null,
      );
      
      if (zipPath != null && mounted) {
        final file = File(zipPath);
        await _saveMetadata(await file.length(), _encryptBackup);
        
        await Share.shareXFiles(
          [XFile(zipPath)],
          text: 'Sthira Backup',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create backup'), backgroundColor: context.colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving backup: $e'), backgroundColor: context.colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _promptForPassword() async {
    final TextEditingController pc = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Encrypted Backup', style: TextStyle(color: context.colors.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This backup is encrypted. Please enter the password to unlock it.'),
            SizedBox(height: 16),
            TextField(
              controller: pc,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, pc.text),
            child: Text('Unlock'),
          ),
        ],
      ),
    );
  }

  /// Android SAF often returns [PlatformFile.path] == null. Prefer path when
  /// present; otherwise write [PlatformFile.bytes] to a temp file.
  Future<String?> _resolvePickedZipPath(PlatformFile file) async {
    final path = file.path;
    if (path != null && path.isNotEmpty) {
      return path;
    }

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not read the selected file. Try again or pick from Downloads.',
            ),
            backgroundColor: context.colors.red,
          ),
        );
      }
      return null;
    }

    final tempDir = await getTemporaryDirectory();
    final name = (file.name.isNotEmpty) ? file.name : 'trufit_restore.zip';
    final safeName = name.toLowerCase().endsWith('.zip') ? name : '$name.zip';
    final tempFile = File(
      '${tempDir.path}/picked_${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile.path;
  }

  Future<void> _handleVerifyBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final path = await _resolvePickedZipPath(result.files.single);
    if (path == null) return;

    setState(() => _isLoading = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      var verify = await backupService.verifyBackup(path);

      if (!mounted) return;

      if (verify.isEncrypted && !verify.isValid) {
        setState(() => _isLoading = false);
        final pwd = await _promptForPassword();
        if (pwd == null || pwd.isEmpty) return;

        setState(() => _isLoading = true);
        verify = await backupService.verifyBackup(path, password: pwd);
        if (!mounted) return;
      }

      if (verify.isValid) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Backup Verified ✨', style: TextStyle(color: context.colors.green)),
            content: Text(
              'App Version: ${verify.appVersion}\n'
              'Created At: ${verify.createdAt != 'Unknown' ? DateFormat('MMM dd, yyyy · HH:mm').format(DateTime.parse(verify.createdAt)) : 'Unknown'}\n'
              'Entries: ${verify.totalEntries}\n'
              'Photos: ${verify.photoCount}\n\n'
              'Your current data was not touched.'
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Awesome')),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Verification Failed', style: TextStyle(color: context.colors.red)),
            content: Text(verify.errorMessage ?? 'Invalid backup file.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Verification Error', style: TextStyle(color: context.colors.red)),
            content: Text('An error occurred while verifying the backup: $e'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final path = await _resolvePickedZipPath(result.files.single);
    if (path == null) return;

    setState(() => _isLoading = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      var verify = await backupService.verifyBackup(path);

      if (!mounted) return;

      String? passwordUsed;
      if (verify.isEncrypted && !verify.isValid) {
        setState(() => _isLoading = false);
        passwordUsed = await _promptForPassword();
        if (passwordUsed == null || passwordUsed.isEmpty) return;

        setState(() => _isLoading = true);
        verify = await backupService.verifyBackup(path, password: passwordUsed);
        if (!mounted) return;
      }

      if (!verify.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid backup file.'), backgroundColor: context.colors.red),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Restore Backup?'),
          content: Text(
            'App Version: ${verify.appVersion}\n'
            'Created At: ${verify.createdAt != 'Unknown' ? DateFormat('MMM dd, yyyy · HH:mm').format(DateTime.parse(verify.createdAt)) : 'Unknown'}\n'
            'Entries: ${verify.totalEntries}\n'
            'Photos: ${verify.photoCount}\n\n'
            'WARNING: Restoring will completely overwrite all your current data. A pre-restore safety backup will be created in your app documents directory.'
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                  try {
                  final result = await backupService.restoreBackup(path, password: passwordUsed);

                  if (!mounted) return;

                  if (result.success) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => AlertDialog(
                        title: Text(result.failedPhotosCount > 0 ? 'Restore Complete (with errors)' : 'Restore Complete 🎉',
                          style: TextStyle(color: result.failedPhotosCount > 0 ? context.colors.orange : context.colors.green)),
                        content: Text(result.failedPhotosCount > 0
                          ? 'Restore complete, but ${result.failedPhotosCount} photos failed to decrypt and were skipped. Please restart the app.'
                          : 'Restore complete — please restart the app.'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to restore backup.'), backgroundColor: context.colors.red),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    final errorMsg = e.toString().replaceFirst('FormatException: ', '');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Restore error: $errorMsg'), backgroundColor: context.colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: Text('Restore', style: TextStyle(color: context.colors.red)),
            ),
          ],
        ),
      ).then((_) {
        // If dialog was dismissed without restoring, loading should be cleared,
        // but we only set _isLoading = false if we didn't start the restore.
        // Let's just handle it securely here.
        if (mounted) setState(() => _isLoading = false);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e'), backgroundColor: context.colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: Text('Backup & Restore'),
        backgroundColor: context.colors.scaffoldBg,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.colors.lavender,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Last Backup',
                              style: TextStyle(fontSize: 14, color: context.colors.textMedium),
                            ),
                            if (_isLastBackupEncrypted) ...[
                              SizedBox(width: 4),
                              Icon(Icons.lock_rounded, size: 14, color: context.colors.textMedium),
                            ],
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          _lastBackupDate,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.colors.primary,
                          ),
                        ),
                        if (_lastBackupSize.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            _lastBackupSize,
                            style: TextStyle(fontSize: 12, color: context.colors.textMedium),
                          ),
                        ],
                        SizedBox(height: 12),
                        Divider(color: context.colors.border),
                        SizedBox(height: 8),
                        Text(
                          'Last Auto-Backup (Weekly)',
                          style: TextStyle(fontSize: 14, color: context.colors.textMedium),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _lastAutoBackupDate,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textDark),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),
                  Row(
                    children: [
                      Text(
                        'Encrypt Backup',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.textDark),
                      ),
                      Spacer(),
                      Switch(
                        value: _encryptBackup,
                        onChanged: (val) {
                          setState(() {
                            _encryptBackup = val;
                            if (!val) _passwordController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  if (_encryptBackup) ...[
                    SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Backup Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  _ActionCard(
                    title: 'Create Backup',
                    subtitle: 'Export a copy of all your data',
                    icon: Icons.upload_file_rounded,
                    onTap: _handleCreateBackup,
                  ),
                  SizedBox(height: 16),
                  _ActionCard(
                    title: 'Restore from Backup',
                    subtitle: 'Overwrite current data with a backup',
                    icon: Icons.restore_page_rounded,
                    iconColor: context.colors.pinkIcon,
                    onTap: _handleRestoreBackup,
                  ),
                  SizedBox(height: 16),
                  _ActionCard(
                    title: 'Verify Backup',
                    subtitle: 'Test a backup file without restoring',
                    icon: Icons.fact_check_rounded,
                    iconColor: context.colors.mintIcon,
                    onTap: _handleVerifyBackup,
                  ),
                ],
              ),
            ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.colors.textDark.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (iconColor ?? context.colors.primary).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor ?? context.colors.primary),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textDark)),
                  SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: context.colors.textMedium)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.textLight),
          ],
        ),
      ),
    );
  }
}
