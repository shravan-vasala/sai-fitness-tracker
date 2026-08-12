import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import 'photo_viewer_screen.dart'; // To reuse PhotoItem

class PhotoCompareScreen extends ConsumerStatefulWidget {
  const PhotoCompareScreen({super.key});

  @override
  ConsumerState<PhotoCompareScreen> createState() => _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends ConsumerState<PhotoCompareScreen> {
  PhotoItem? _leftPhoto;
  PhotoItem? _rightPhoto;
  List<PhotoItem> _allPhotos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPhotos();
    });
  }

  void _initPhotos() {
    final mediaRepo = ref.read(mediaRepoProvider);
    final allEntries = mediaRepo.getAllProgressPhotos();
    
    _allPhotos = [];
    for (final entry in allEntries) {
      final date = entry.key;
      for (final path in entry.value) {
        final poseTag = mediaRepo.getPoseTag(path);
        _allPhotos.add(PhotoItem(path: path, date: date, poseTag: poseTag));
      }
    }
    
    if (_allPhotos.isEmpty) return;

    // allPhotos is sorted newest to oldest because getAllProgressPhotos sorts descending by date.
    // Right photo = newest, Left photo = most recent photo from a PREVIOUS date.
    PhotoItem rightPhoto = _allPhotos.first;
    PhotoItem? leftPhoto;

    // Try to find matching poses on different dates first
    final poses = _allPhotos.map((p) => p.poseTag).where((p) => p != 'none').toSet();
    if (poses.isNotEmpty) {
      for (final pose in poses) {
        final posePhotos = _allPhotos.where((p) => p.poseTag == pose).toList();
        // Find two photos with the same pose but different dates
        if (posePhotos.length > 1) {
          final newestPose = posePhotos.first;
          // Find the next photo with a different date
          final olderPose = posePhotos.skip(1).where((p) => p.date != newestPose.date).firstOrNull;
          if (olderPose != null) {
            rightPhoto = newestPose;
            leftPhoto = olderPose;
            break;
          }
        }
      }
    }

    // Fallback: pick any photo from a different date
    leftPhoto ??= _allPhotos.where((p) => p.date != rightPhoto.date).firstOrNull;

    // Last resort: if only one date exists, use the last photo as left
    leftPhoto ??= _allPhotos.length > 1 ? _allPhotos.last : null;
    
    setState(() {
      _leftPhoto = leftPhoto;
      _rightPhoto = rightPhoto;
    });
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _getTimeDeltaText() {
    if (_leftPhoto == null || _rightPhoto == null) return '';
    try {
      final d1 = DateTime.parse(_leftPhoto!.date);
      final d2 = DateTime.parse(_rightPhoto!.date);
      final diff = d2.difference(d1).inDays.abs();
      if (diff == 0) return 'Same day';
      if (diff < 30) return '$diff days apart';
      final months = (diff / 30).round();
      if (months == 1) return '1 month apart';
      if (months < 12) return '$months months apart';
      final years = (months / 12).toStringAsFixed(1);
      return '$years years apart';
    } catch (_) {
      return '';
    }
  }

  String _getWeightStr(String date) {
    final log = ref.read(dailyLogRepoProvider).getLog(date);
    if (log != null && log.weight != null) {
      return '${log.weight} kg';
    }
    return '—';
  }

  void _pickPhoto(bool isLeft) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.scaffoldBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Select Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _allPhotos.length,
                itemBuilder: (ctx, i) {
                  final item = _allPhotos[i];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isLeft) {
                          _leftPhoto = item;
                        } else {
                          _rightPhoto = item;
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? Image.network(item.path, fit: BoxFit.cover)
                                : Image.file(File(item.path), fit: BoxFit.cover),
                          ),
                        ),
                        if (item.poseTag != 'none')
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.poseTag,
                                style: TextStyle(fontSize: 9, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoColumn(PhotoItem? item, bool isLeft) {
    if (item == null) {
      return Expanded(
        child: GestureDetector(
          onTap: () => _pickPhoto(isLeft),
          child: Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_photo_alternate, color: Colors.white54, size: 48),
                  SizedBox(height: 8),
                  Text('Select Photo', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => _pickPhoto(isLeft),
        child: Container(
          color: Colors.black,
          child: Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: kIsWeb
                        ? Image.network(item.path, fit: BoxFit.contain)
                        : Image.file(File(item.path), fit: BoxFit.contain),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                color: Colors.black87,
                child: Column(
                  children: [
                    Text(
                      _formatDate(item.date),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _getWeightStr(item.date),
                      style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text('Compare', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Row(
              children: [
                _buildPhotoColumn(_leftPhoto, true),
                Container(width: 2, color: Colors.white24),
                _buildPhotoColumn(_rightPhoto, false),
              ],
            ),
          ),
          if (_leftPhoto != null && _rightPhoto != null && _getTimeDeltaText().isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: 32,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _getTimeDeltaText(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
