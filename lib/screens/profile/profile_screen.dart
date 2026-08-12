import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_colors.dart';
import '../../theme/layout_insets.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_sync_service.dart';
import '../../services/screen_time_service.dart';
import 'package:intl/intl.dart';


class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${info.version}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            children: [
              SizedBox(height: 8),
              // Profile header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.primary.withValues(alpha: 0.1),
                        border: Border.all(
                          color: context.colors.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: profile.photoPath != null && File(profile.photoPath!).existsSync()
                            ? Image.file(
                                File(profile.photoPath!),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                            : Center(
                                child: profile.name.isNotEmpty
                                    ? Text(
                                        profile.name[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: context.colors.primary,
                                        ),
                                      )
                                    : Icon(Icons.person, size: 40, color: context.colors.primary),
                              ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      profile.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Height: ${profile.height.toStringAsFixed(0)} cm',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.textMedium,
                      ),
                    ),
                    if (profile.targetWeight != null) ...[
                      SizedBox(height: 2),
                      Text(
                        'Target: ${profile.targetWeight!.toStringAsFixed(1)} ${profile.weightUnit}',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.textMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 24),
              
              // Cloud Sync
              const _CloudSyncCard(),
              SizedBox(height: 16),

              // Menu items
              _MenuCard(
                icon: Icons.edit_rounded,
                title: 'Edit Profile',
                subtitle: 'Name, height, target weight',
                onTap: () {
                  showAppBottomSheet(
                    context: context,
                    builder: (ctx) => const _EditProfileSheet(),
                  );
                },
              ),
              _MenuCard(
                icon: Icons.auto_awesome_rounded,
                title: 'AI Settings',
                subtitle: 'Coach name & Gemini API key (optional)',
                onTap: () => _showGeminiKeyDialog(context, ref, profile),
              ),
              _MenuCard(
                icon: Icons.fitness_center_rounded,
                title: 'Manage Plans',
                subtitle: 'Edit workout & meal JSON',
                onTap: () => context.go('/profile/manage-plans'),
              ),
              _MenuCard(
                icon: Icons.notifications_rounded,
                title: 'Reminders',
                subtitle: 'Daily habits, workouts, and backups',
                onTap: () => context.go('/profile/reminders'),
              ),
              _MenuCard(
                icon: Icons.swap_horiz_rounded,
                title: 'Unit Preference',
                subtitle: 'Currently: ${profile.useKg ? 'Kilograms (kg)' : 'Pounds (lb)'}',
                onTap: () {
                  ref.read(profileProvider.notifier).toggleUnit();
                },
              ),
              _MenuCard(
                icon: Icons.dark_mode_rounded,
                title: 'Theme',
                subtitle: 'Currently: ${_themeLabel(ref.watch(themeModeProvider))}',
                onTap: () => _showThemeDialog(context, ref),
              ),
              _SettingsSwitch(
                icon: Icons.volume_up_rounded,
                title: 'Rest Timer Sound',
                subtitle: 'Play alert sound when rest finishes',
                value: profile.restTimerSound,
                onChanged: (val) {
                  ref.read(profileProvider.notifier).updateProfile(
                        profile.copyWith(restTimerSound: val),
                      );
                },
              ),
              if (Platform.isAndroid)
                _SettingsSwitch(
                  icon: Icons.smartphone_rounded,
                  title: 'Screen Time Tracking',
                  subtitle: profile.screenTimeEnabled 
                      ? 'Enabled (Tracks device screen time)' 
                      : 'Disabled (Opt-in to track screen time)',
                  value: profile.screenTimeEnabled,
                  onChanged: (val) async {
                    if (val) {
                      // Attempt to enable
                      final hasPermission = await ref.read(screenTimeServiceProvider).checkPermission();
                      if (hasPermission) {
                        ref.read(profileProvider.notifier).updateProfile(
                          profile.copyWith(screenTimeEnabled: true),
                        );
                      } else {
                        if (context.mounted) {
                          _showScreenTimePermissionDialog(context, ref, profile);
                        }
                      }
                    } else {
                      // Disable
                      ref.read(profileProvider.notifier).updateProfile(
                        profile.copyWith(screenTimeEnabled: false),
                      );
                    }
                  },
                ),
              _SettingsSwitch(
                icon: Icons.vibration_rounded,
                title: 'Rest Timer Vibration',
                subtitle: 'Vibrate when rest finishes',
                value: profile.restTimerVibration,
                onChanged: (val) {
                  ref.read(profileProvider.notifier).updateProfile(
                        profile.copyWith(restTimerVibration: val),
                      );
                },
              ),
              _MenuCard(
                icon: Icons.backup_rounded,
                title: 'Backup & Restore',
                subtitle: 'Export or restore all data & photos',
                onTap: () {
                  context.go('/profile/backup-restore');
                },
              ),
              _MenuCard(
                icon: Icons.table_chart_rounded,
                title: 'Export Data',
                subtitle: 'Download logs and stats as CSV',
                onTap: () => _showExportDataSheet(context, ref),
              ),
              SizedBox(height: 16),
              Text(
                'Made with love by Shravan Vasala',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textLight,
                ),
              ),
              if (_appVersion.isNotEmpty) ...[
                SizedBox(height: 4),
                Text(
                  _appVersion,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.colors.textLight.withValues(alpha: 0.6),
                  ),
                ),
              ],
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showScreenTimePermissionDialog(BuildContext context, WidgetRef ref, dynamic profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text('Enable Screen Time', style: TextStyle(color: context.colors.textDark)),
        content: Text(
          'Sthira can read your daily screen time to help you build better habits. '
          'This requires "Usage Access" permission.\n\n'
          'Your screen time is only stored locally on this device, and will only be synced to your private cloud if Cloud Sync is enabled.',
          style: TextStyle(color: context.colors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.colors.textLight)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(screenTimeServiceProvider).openSettings();
            },
            child: Text('Open Settings', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    showAppBottomSheet(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final current = ref.watch(themeModeProvider);
            final colors = context.colors;

            String label(ThemeMode mode) {
              switch (mode) {
                case ThemeMode.system:
                  return 'System';
                case ThemeMode.light:
                  return 'Light';
                case ThemeMode.dark:
                  return 'Dark';
              }
            }

            String subtitle(ThemeMode mode) {
              switch (mode) {
                case ThemeMode.system:
                  return 'Match phone settings';
                case ThemeMode.light:
                  return 'Always light';
                case ThemeMode.dark:
                  return 'Always dark';
              }
            }

            IconData icon(ThemeMode mode) {
              switch (mode) {
                case ThemeMode.system:
                  return Icons.brightness_auto_rounded;
                case ThemeMode.light:
                  return Icons.light_mode_rounded;
                case ThemeMode.dark:
                  return Icons.dark_mode_rounded;
              }
            }

            return AppSheet(
              title: 'Select Theme',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: ThemeMode.values.map((mode) {
                  final selected = current == mode;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      icon(mode),
                      color: selected ? colors.primary : colors.textMedium,
                    ),
                    title: Text(
                      label(mode),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.textDark,
                      ),
                    ),
                    subtitle: Text(
                      subtitle(mode),
                      style: TextStyle(color: colors.textMedium, fontSize: 13),
                    ),
                    trailing: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected ? colors.primary : colors.border,
                    ),
                    onTap: () async {
                      await ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(mode);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  void _showGeminiKeyDialog(
      BuildContext context, WidgetRef ref, dynamic profile) {
    final keyController = TextEditingController(text: profile.geminiApiKey ?? '');
    final coachController = TextEditingController(text: profile.coachName as String? ?? '');
    
    showAppBottomSheet(
      context: context,
      builder: (ctx) => AppSheet(
        title: 'AI & Coach Settings',
        scrollable: true,
        subtitle:
            'Set your coach\'s name for daily notes. A Gemini API key is ONLY required if you are not using Cloud Sync.',
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: coachController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Coach name',
                hintText: '',                prefixIcon: Icon(Icons.sports_rounded),
                filled: true,
                fillColor: context.colors.inputFill,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                prefixIcon: Icon(Icons.key_rounded),
                filled: true,
                fillColor: context.colors.inputFill,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save',
              onPressed: () async {
                final key = keyController.text.trim();
                final coachName = coachController.text.trim();
                
                if (key.isNotEmpty) {
                  try {
                    await ref.read(geminiFoodServiceProvider).verifyApiKey(key);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                      );
                    }
                    return; // Abort save if key is invalid
                  }
                }

                final current = ref.read(profileProvider);
                
                await ref.read(profileProvider.notifier).updateProfile(
                      current.copyWith(
                        coachName: coachName,
                        geminiApiKey: key,
                      ),
                    );
                await ref.read(profileProvider.notifier).updateGeminiKey(key);
                
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _showExportDataSheet(BuildContext context, WidgetRef ref) {
    showAppBottomSheet(
      context: context,
      builder: (sheetContext) => AppSheet(
        title: 'Export Data (CSV)',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExportOptionTile(
              title: 'Last 30 Days',
              onTap: () {
                // Sheet is on the root navigator; pop with sheet context.
                Navigator.of(sheetContext).pop();
                _handleExport(
                  context,
                  ref,
                  DateTime.now().subtract(const Duration(days: 30)),
                );
              },
            ),
            _ExportOptionTile(
              title: 'Last 90 Days',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleExport(
                  context,
                  ref,
                  DateTime.now().subtract(const Duration(days: 90)),
                );
              },
            ),
            _ExportOptionTile(
              title: 'All Time',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleExport(context, ref, null);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    WidgetRef ref,
    DateTime? startDate,
  ) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final exportService = ref.read(csvExportServiceProvider);
      final zipPath = await exportService.exportData(startDate);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // hide loading

      if (zipPath != null) {
        await Share.shareXFiles(
          [XFile(zipPath)],
          text: 'TruFit Data Export',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export data or no data found'),
            backgroundColor: context.colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // hide loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: $e'),
          backgroundColor: context.colors.red,
        ),
      );
    }
  }
}

class _CloudSyncCard extends ConsumerStatefulWidget {
  const _CloudSyncCard();

  @override
  ConsumerState<_CloudSyncCard> createState() => _CloudSyncCardState();
}

class _CloudSyncCardState extends ConsumerState<_CloudSyncCard> {
  bool _isSyncing = false;
  String _syncStatus = '';

  Future<void> _handleSignIn() async {
    setState(() { _isSyncing = true; _syncStatus = 'Signing in...'; });
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      if (user != null && mounted) {
        // Run initial sync/migration
        setState(() { _syncStatus = 'Syncing data...'; });
        await _runFullSync();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully signed in & synced!'), backgroundColor: context.colors.primary),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e'), backgroundColor: context.colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isSyncing = false; _syncStatus = ''; });
    }
  }

  Future<void> _runFullSync() async {
    final syncService = ref.read(firestoreSyncServiceProvider);
    
    // 1. Check if cloud has data
    final hasCloudData = await syncService.hasCloudData();
    
    if (hasCloudData) {
      // Pull down to device
      final profile = await syncService.pullProfile();
      await ref.read(profileRepoProvider).importProfileFromCloud(profile);
      
      final dailyLogs = await syncService.pullCollection('daily_logs');
      await ref.read(dailyLogRepoProvider).importFromCloud(dailyLogs);
      
      final mealLogs = await syncService.pullCollection('meal_logs');
      await ref.read(mealRepoProvider).importLogsFromCloud(mealLogs);
      
      final stats = await syncService.pullCollection('body_stats');
      await ref.read(bodyStatsRepoProvider).importStatsFromCloud(stats);
      
      final workoutPlans = await syncService.pullCollection('workout_plans');
      await ref.read(workoutRepoProvider).importPlansFromCloud(workoutPlans);
      
      final mealPlans = await syncService.pullCollection('meal_plans');
      await ref.read(mealRepoProvider).importPlansFromCloud(mealPlans);
      
      // refresh UI
      ref.invalidate(profileProvider);
      ref.invalidate(dailyLogProvider);
      ref.invalidate(dailyMealLogProvider);
      ref.invalidate(latestBodyStatsProvider);
    } else {
      // First time cloud user: upload local data
      syncService.syncProfile(ref.read(profileRepoProvider).exportProfileForCloud());
      await syncService.bulkSync('daily_logs', ref.read(dailyLogRepoProvider).exportForCloud());
      await syncService.bulkSync('meal_logs', ref.read(mealRepoProvider).exportLogsForCloud());
      await syncService.bulkSync('body_stats', ref.read(bodyStatsRepoProvider).exportStatsForCloud());
      await syncService.bulkSync('habit_config', ref.read(habitRepoProvider).exportConfigForCloud());
      await syncService.bulkSync('habit_completions', ref.read(habitRepoProvider).exportCompletionsForCloud());
      await syncService.bulkSync('workout_plans', ref.read(workoutRepoProvider).exportPlansForCloud());
      await syncService.bulkSync('meal_plans', ref.read(mealRepoProvider).exportPlansForCloud());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final userEmail = ref.watch(userEmailProvider);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_rounded, color: context.colors.primary),
              SizedBox(width: 8),
              Text(
                'Cloud Sync',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textDark,
                ),
              ),
              Spacer(),
              if (isSignedIn)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(fontSize: 12, color: context.colors.green, fontWeight: FontWeight.bold),
                  ),
                )
            ],
          ),
          SizedBox(height: 12),
          Text(
            isSignedIn 
              ? 'Your text data is securely synced as $userEmail. Photos are NOT cloud-synced. Use ZIP backup to move media.'
              : 'Sign in to sync your text data across devices. Photos are NOT cloud-synced.',
            style: TextStyle(color: context.colors.textMedium, fontSize: 13),
          ),
          SizedBox(height: 16),
          if (_isSyncing)
            Center(
              child: Column(
                children: [
                  SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(height: 8),
                  Text(_syncStatus, style: TextStyle(color: context.colors.primary, fontSize: 12)),
                ],
              ),
            )
          else if (!isSignedIn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(Icons.login),
                label: Text('Sign in with Google'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      setState(() { _isSyncing = true; _syncStatus = 'Syncing...'; });
                      await _runFullSync();
                      setState(() { _isSyncing = false; _syncStatus = ''; });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary,
                      side: BorderSide(color: context.colors.primary.withValues(alpha: 0.5)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.sync),
                    label: Text('Sync Now'),
                  ),
                ),
                SizedBox(width: 12),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: context.colors.card,
                        title: Text('Sign Out', style: TextStyle(color: context.colors.textDark)),
                        content: Text('Are you sure you want to sign out?', style: TextStyle(color: context.colors.textMedium)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancel', style: TextStyle(color: context.colors.textLight)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('Sign Out', style: TextStyle(color: context.colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(authServiceProvider).signOut();
                    }
                  },
                  tooltip: 'Sign out',
                  icon: Icon(Icons.logout, color: context.colors.red),
                  style: IconButton.styleFrom(
                    backgroundColor: context.colors.red.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _ExportOptionTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 24),
      title: Text(title, style: TextStyle(color: context.colors.textDark, fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.chevron_right_rounded, color: context.colors.textMedium),
      onTap: onTap,
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(kCardRadius),
          boxShadow: [
            BoxShadow(
              color: context.colors.primary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.colors.lavender,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: context.colors.primary, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colors.textLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: context.colors.primary,
        secondary: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.lavender,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: context.colors.primary, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: context.colors.textMedium,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kCardRadius)),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late TextEditingController nameController;
  late TextEditingController coachNameController;
  late TextEditingController heightController;
  late TextEditingController targetController;
  late TextEditingController caloriesController;
  late TextEditingController proteinController;
  late TextEditingController carbsController;
  late TextEditingController fatController;
  
  String? _localPhotoPath;
  bool _clearPhoto = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    nameController = TextEditingController(text: profile.name);
    coachNameController = TextEditingController(text: profile.coachName);
    heightController = TextEditingController(text: profile.height.toStringAsFixed(0));
    targetController = TextEditingController(text: profile.targetWeight?.toStringAsFixed(1) ?? '');
    caloriesController = TextEditingController(text: profile.targetCalories.toString());
    proteinController = TextEditingController(text: profile.targetProteinG.toString());
    carbsController = TextEditingController(text: profile.targetCarbsG.toString());
    fatController = TextEditingController(text: profile.targetFatG.toString());
    _localPhotoPath = profile.photoPath;
  }

  @override
  void dispose() {
    nameController.dispose();
    coachNameController.dispose();
    heightController.dispose();
    targetController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: context.colors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'profile_pic_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await File(croppedFile.path).copy('${appDir.path}/$fileName');
        
        setState(() {
          _localPhotoPath = savedImage.path;
          _clearPhoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'), backgroundColor: context.colors.red),
        );
      }
    }
  }

  void _showPickerOptions() {
    showAppBottomSheet(
      context: context,
      builder: (ctx) => AppSheet(
        title: 'Profile Photo',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.camera_alt, color: context.colors.primary),
              title: const Text('Take a picture'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.photo_library, color: context.colors.primary),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_localPhotoPath != null && !_clearPhoto)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete, color: context.colors.red),
                title: Text('Remove photo', style: TextStyle(color: context.colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (_localPhotoPath != null) {
                    final f = File(_localPhotoPath!);
                    if (await f.exists()) await f.delete();
                  }
                  setState(() {
                    _localPhotoPath = null;
                    _clearPhoto = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return AppSheet(
      title: 'Edit Profile',
      scrollable: true,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _showPickerOptions,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.lavenderCard,
                      ),
                      child: ClipOval(
                        child: _localPhotoPath != null && !_clearPhoto
                            ? Image.file(
                                File(_localPhotoPath!),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                            : Center(
                                child: nameController.text.isNotEmpty
                                    ? Text(
                                        nameController.text[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: context.colors.primary,
                                        ),
                                      )
                                    : Icon(Icons.person, size: 40, color: context.colors.primary),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.colors.card, width: 2),
                        ),
                        child: Icon(Icons.camera_alt, color: context.colors.onPrimary, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _ProfileTextField(
              label: 'Name',
              controller: nameController,
              prefixIcon: Icons.person_rounded,
              onChanged: (v) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _ProfileTextField(
              label: 'Coach name',
              controller: coachNameController,
              prefixIcon: Icons.sports_rounded,
            ),
            const SizedBox(height: 16),
            _ProfileTextField(
              label: 'Height (cm)',
              controller: heightController,
              prefixIcon: Icons.height_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _ProfileTextField(
              label: 'Target Weight (kg)',
              controller: targetController,
              prefixIcon: Icons.flag_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            _ProfileTextField(
              label: 'Target Daily Calories',
              controller: caloriesController,
              prefixIcon: Icons.restaurant_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Text(
              'Daily macros (g)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ProfileTextField(
                    label: 'Protein',
                    controller: proteinController,
                    prefixIcon: Icons.fitness_center_rounded,
                    keyboardType: TextInputType.number,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ProfileTextField(
                    label: 'Carbs',
                    controller: carbsController,
                    prefixIcon: Icons.breakfast_dining_rounded,
                    keyboardType: TextInputType.number,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ProfileTextField(
                    label: 'Fat',
                    controller: fatController,
                    prefixIcon: Icons.water_drop_rounded,
                    keyboardType: TextInputType.number,
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Save',
              onPressed: () {
                final updated = profile.copyWith(
                  name: nameController.text,
                  coachName: coachNameController.text.trim(),
                  height: double.tryParse(heightController.text) ??
                      profile.height,
                  targetWeight: double.tryParse(targetController.text),
                  targetCalories: int.tryParse(caloriesController.text) ??
                      profile.targetCalories,
                  targetProteinG: int.tryParse(proteinController.text) ?? profile.targetProteinG,
                  targetCarbsG: int.tryParse(carbsController.text) ?? profile.targetCarbsG,
                  targetFatG: int.tryParse(fatController.text) ?? profile.targetFatG,
                  photoPath: _localPhotoPath,
                  clearPhoto: _clearPhoto,
                );
                ref.read(profileProvider.notifier).updateProfile(updated);
                Navigator.of(context).pop();
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.label,
    required this.controller,
    required this.prefixIcon,
    this.keyboardType,
    this.onChanged,
    this.compact = false,
  });

  final String label;
  final TextEditingController controller;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textMedium,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: context.colors.textDark,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.colors.inputFill,
            prefixIcon: Icon(
              prefixIcon,
              size: compact ? 18 : 22,
              color: context.colors.primary,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 14 : 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.colors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.colors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
