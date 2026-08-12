import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/layout_insets.dart';
import '../../providers/app_providers.dart';
import 'photo_viewer_screen.dart';
import 'photo_compare_screen.dart';

class PhysiquePicturesScreen extends ConsumerStatefulWidget {
  const PhysiquePicturesScreen({super.key});

  @override
  ConsumerState<PhysiquePicturesScreen> createState() =>
      _PhysiquePicturesScreenState();
}

class _PhysiquePicturesScreenState
    extends ConsumerState<PhysiquePicturesScreen> {
  final _picker = ImagePicker();

  bool _isSelectionMode = false;
  final Set<String> _selectedPhotos = {};
  String _currentFilter = 'all';

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPhotos.contains(path)) {
        _selectedPhotos.remove(path);
        if (_selectedPhotos.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPhotos.add(path);
      }
    });
  }

  void _deleteSelected(Map<String, List<String>> photosByDate) {
    if (_selectedPhotos.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Photos?'),
        content: Text('Delete ${_selectedPhotos.length} photo(s)? This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              // Map selected paths back to their dates
              final toDelete = <String, List<String>>{};
              for (final path in _selectedPhotos) {
                // Find date for this path
                for (final entry in photosByDate.entries) {
                  if (entry.value.contains(path)) {
                    toDelete.putIfAbsent(entry.key, () => []).add(path);
                    break;
                  }
                }
              }

              await ref.read(mediaRepoProvider).deletePhotos(toDelete);
              setState(() {
                _selectedPhotos.clear();
                _isSelectionMode = false;
              });
            },
            child: Text('Delete', style: TextStyle(color: context.colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaRepo = ref.watch(mediaRepoProvider);
    final rawPhotos = mediaRepo.getAllProgressPhotos();
    
    // Filter the photos based on _currentFilter
    final allPhotos = <MapEntry<String, List<String>>>[];
    for (final entry in rawPhotos) {
      final date = entry.key;
      final filteredPaths = <String>[];
      for (final path in entry.value) {
        final meta = mediaRepo.getProgressPhotoMeta(date, path);
        if (_currentFilter == 'all' || meta.pose == _currentFilter) {
          filteredPaths.add(path);
        }
      }
      if (filteredPaths.isNotEmpty) {
        allPhotos.add(MapEntry(date, filteredPaths));
      }
    }

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: Text(_isSelectionMode ? '${_selectedPhotos.length} Selected' : 'Physique Pictures'),
        leading: IconButton(
          icon: Icon(_isSelectionMode ? Icons.close_rounded : Icons.arrow_back_ios_rounded),
          onPressed: () {
            if (_isSelectionMode) {
              setState(() {
                _isSelectionMode = false;
                _selectedPhotos.clear();
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: context.colors.red),
              onPressed: () {
                final Map<String, List<String>> photosByDate = {};
                for (final entry in allPhotos) {
                  photosByDate[entry.key] = entry.value;
                }
                _deleteSelected(photosByDate);
              },
            )
          else if (allPhotos.isNotEmpty)
            TextButton.icon(
              onPressed: () => _openCompareMode(allPhotos),
              icon: Icon(Icons.compare_rounded, color: context.colors.primary),
              label: Text('Compare', style: TextStyle(color: context.colors.primary)),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: kFloatingNavClearance),
        child: FloatingActionButton(
          onPressed: _addPhoto,
          backgroundColor: context.colors.primary,
          child: Icon(Icons.add_a_photo_rounded, color: context.colors.onPrimary),
        ),
      ),
      body: Column(
        children: [
          // Filter Toggle
          if (rawPhotos.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _currentFilter == 'all',
                      onTap: () => setState(() => _currentFilter = 'all'),
                    ),
                    SizedBox(width: 8),
                    _FilterChip(
                      label: 'Front',
                      isSelected: _currentFilter == 'front',
                      onTap: () => setState(() => _currentFilter = 'front'),
                    ),
                    SizedBox(width: 8),
                    _FilterChip(
                      label: 'Side',
                      isSelected: _currentFilter == 'side',
                      onTap: () => setState(() => _currentFilter = 'side'),
                    ),
                    SizedBox(width: 8),
                    _FilterChip(
                      label: 'Back',
                      isSelected: _currentFilter == 'back',
                      onTap: () => setState(() => _currentFilter = 'back'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: rawPhotos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 64,
                          color: context.colors.textLight.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No progress photos yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textMedium,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap the + button to add your first photo',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textLight,
                          ),
                        ),
                      ],
                    ),
                  )
                : allPhotos.isEmpty 
                    ? Center(
                        child: Text(
                          'No photos for this pose.',
                          style: TextStyle(color: context.colors.textMedium),
                        ),
                      )
                    : ListView.builder(
                        physics: BouncingScrollPhysics(),
                        padding: EdgeInsets.all(20),
              itemCount: allPhotos.length,
              itemBuilder: (context, index) {
                final entry = allPhotos[index];
                final date = entry.key;
                final photos = entry.value;
                final formattedDate = _formatDate(date);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textDark,
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: photos.length,
                      itemBuilder: (context, i) {
                        final photoPath = photos[i];
                        final meta = ref.read(mediaRepoProvider).getProgressPhotoMeta(date, photoPath);
                        final poseTag = meta.pose;
                        final weight = meta.weight;

                        final isSelected = _selectedPhotos.contains(photoPath);

                        return GestureDetector(
                          onLongPress: () {
                            if (!_isSelectionMode) {
                              setState(() {
                                _isSelectionMode = true;
                                _selectedPhotos.add(photoPath);
                              });
                            }
                          },
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(photoPath);
                            } else {
                              _openViewer(allPhotos, index, i);
                            }
                          },
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: kIsWeb
                                      ? Image.network(
                                          photoPath,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, e, s) => Container(
                                            color: context.colors.lavender,
                                            child: Icon(
                                              Icons.broken_image_rounded,
                                              color: context.colors.textLight,
                                            ),
                                          ),
                                        )
                                      : Image.file(
                                          File(photoPath),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, e, s) => Container(
                                            color: context.colors.lavender,
                                            child: Icon(
                                              Icons.broken_image_rounded,
                                              color: context.colors.textLight,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              if (poseTag != 'none')
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.colors.textDark.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      poseTag.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: context.colors.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              if (weight != null)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.colors.primary.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${weight}kg',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: context.colors.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              if (isSelected)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: context.colors.primary.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: context.colors.primary, width: 3),
                                    ),
                                    child: Center(
                                      child: Icon(Icons.check_circle_rounded, color: context.colors.onPrimary, size: 32),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _poseLabel(String tag) {
    switch (tag) {
      case 'front':
        return '🧍 Front';
      case 'side':
        return '🔄 Side';
      case 'back':
        return '🔙 Back';
      default:
        return tag;
    }
  }

  void _openViewer(List<MapEntry<String, List<String>>> allPhotos, int dateIndex, int photoIndex) {
    // Flatten all photos into a list of PhotoItems
    final List<PhotoItem> flatPhotos = [];
    int initialIndex = 0;
    
    for (int d = 0; d < allPhotos.length; d++) {
      final date = allPhotos[d].key;
      final photos = allPhotos[d].value;
      
      for (int p = 0; p < photos.length; p++) {
        final path = photos[p];
        final poseTag = ref.read(mediaRepoProvider).getPoseTag(path);
        
        if (d == dateIndex && p == photoIndex) {
          initialIndex = flatPhotos.length;
        }
        
        flatPhotos.add(PhotoItem(path: path, date: date, poseTag: poseTag));
      }
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          photos: flatPhotos,
          initialIndex: initialIndex,
        ),
      ),
    ).then((_) {
      // Re-fetch in case a photo was deleted
      setState(() {});
    });
  }

  void _openCompareMode(List<MapEntry<String, List<String>>> allPhotos) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoCompareScreen(), // Will implement next
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Progress Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.camera_alt, color: context.colors.primary),
              title: Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: context.colors.primary),
              title: Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final image = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    // Prompt for metadata (Pose, Weight, Note)
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final currentWeight = ref.read(dailyLogRepoProvider).getLog(date)?.weight;

    final metadata = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Photo Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16),
            _CaptureMetadataForm(
              initialWeight: currentWeight ?? 0.0,
              onComplete: (data) => Navigator.pop(ctx, data),
            ),
          ],
        ),
      ),
    );

    if (!mounted || metadata == null) return;
    
    final selectedPose = metadata['pose'] as String;
    final weight = metadata['weight'] as double?;
    final note = metadata['note'] as String?;

    final imageBytes = await image.readAsBytes();
    await ref.read(mediaRepoProvider).saveProgressPhoto(
      date,
      imageBytes,
      poseTag: selectedPose,
      weight: weight,
      note: note,
    );
    setState(() {}); // refresh
  }
}

class _PoseOption extends StatelessWidget {
  const _PoseOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: context.colors.lavender,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: context.colors.primary, size: 28),
            SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.colors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureMetadataForm extends StatefulWidget {
  final double initialWeight;
  final Function(Map<String, dynamic>) onComplete;

  const _CaptureMetadataForm({
    required this.initialWeight,
    required this.onComplete,
  });

  @override
  State<_CaptureMetadataForm> createState() => _CaptureMetadataFormState();
}

class _CaptureMetadataFormState extends State<_CaptureMetadataForm> {
  String? _selectedPose;
  late TextEditingController _weightController;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.initialWeight > 0 ? widget.initialWeight.toString() : '',
    );
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pose (Required)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SelectablePoseOption(
                icon: Icons.accessibility_new_rounded,
                label: 'Front',
                isSelected: _selectedPose == 'front',
                onTap: () => setState(() => _selectedPose = 'front'),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _SelectablePoseOption(
                icon: Icons.sync_alt_rounded,
                label: 'Side',
                isSelected: _selectedPose == 'side',
                onTap: () => setState(() => _selectedPose = 'side'),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _SelectablePoseOption(
                icon: Icons.turn_left_rounded,
                label: 'Back',
                isSelected: _selectedPose == 'back',
                onTap: () => setState(() => _selectedPose = 'back'),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        TextField(
          controller: _weightController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Weight (Optional)',
            prefixIcon: Icon(Icons.monitor_weight_outlined),
          ),
        ),
        SizedBox(height: 12),
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
            labelText: 'Note (Optional)',
            prefixIcon: Icon(Icons.notes_rounded),
            hintText: 'e.g. Post-workout pump',
          ),
        ),
        SizedBox(height: 24),
        ElevatedButton(
          onPressed: _selectedPose == null
              ? null
              : () {
                  widget.onComplete({
                    'pose': _selectedPose,
                    'weight': double.tryParse(_weightController.text),
                    'note': _noteController.text,
                  });
                },
          child: Text('Save Photo'),
        ),
      ],
    );
  }
}

class _SelectablePoseOption extends StatelessWidget {
  const _SelectablePoseOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : context.colors.lavender,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? context.colors.onPrimary : context.colors.primary, size: 24),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? context.colors.onPrimary : context.colors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : context.colors.lavender,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? context.colors.onPrimary : context.colors.primary,
          ),
        ),
      ),
    );
  }
}
