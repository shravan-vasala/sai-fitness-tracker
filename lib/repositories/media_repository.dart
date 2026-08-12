import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/progress_photo.dart';

class MediaRepository {
  static const String _boxName = 'media_meta_v2';

  late Box<ProgressPhoto> _box;
  late String _baseDir;

  Future<void> init() async {
    _box = await Hive.openBox<ProgressPhoto>(_boxName);
    if (!kIsWeb) {
      final appDir = await getApplicationDocumentsDirectory();
      _baseDir = '${appDir.path}/trufit_media';
      await Directory(_baseDir).create(recursive: true);
      await Directory('$_baseDir/progress_photos').create(recursive: true);
    } else {
      _baseDir = 'trufit_media';
    }
  }

  // Save a progress photo from raw bytes (works on both web and mobile)
  Future<String> saveProgressPhoto(
    String date,
    Uint8List imageBytes, {
    String poseTag = 'none',
    double? weight,
    String? note,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final destPath = kIsWeb
        ? 'web_photo_${date}_$timestamp.jpg'
        : '$_baseDir/progress_photos/${date}_$timestamp.jpg';

    if (!kIsWeb) {
      final file = File(destPath);
      await file.writeAsBytes(imageBytes);
    }

    // Save detailed metadata
    final meta = ProgressPhoto(
      path: destPath,
      date: date,
      pose: poseTag,
      weight: weight,
      note: note,
    );
    await _box.put(destPath, meta);

    return destPath;
  }

  // Save a progress photo from a file path (legacy, mobile-only)
  Future<String> saveProgressPhotoFromPath(
    String date,
    String sourcePath, {
    String poseTag = 'none',
    double? weight,
    String? note,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final destPath = kIsWeb
        ? sourcePath
        : '$_baseDir/progress_photos/${date}_$timestamp.jpg';

    if (!kIsWeb) {
      await File(sourcePath).copy(destPath);
    }

    // Save detailed metadata
    final meta = ProgressPhoto(
      path: destPath,
      date: date,
      pose: poseTag,
      weight: weight,
      note: note,
    );
    await _box.put(destPath, meta);

    return destPath;
  }

  ProgressPhoto getProgressPhotoMeta(String date, String photoPath) {
    return _box.get(photoPath) ?? ProgressPhoto(path: photoPath, date: date, pose: 'none');
  }

  String getPoseTag(String photoPath) {
    return _box.get(photoPath)?.pose ?? 'none';
  }

  List<String> getProgressPhotos(String date) {
    return _box.values.where((p) => p.date == date).map((p) => p.path).toList();
  }

  List<MapEntry<String, List<String>>> getAllProgressPhotos() {
    final grouped = <String, List<String>>{};
    for (final photo in _box.values) {
      grouped.putIfAbsent(photo.date, () => []).add(photo.path);
    }
    final result = grouped.entries.toList();
    result.sort((a, b) => b.key.compareTo(a.key));
    return result;
  }

  List<ProgressPhoto> getAllProgressPhotosDetailed() {
    final result = _box.values.toList();
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  int getAllPhotoCount() {
    return _box.length;
  }

  Future<void> deletePhoto(String date, String photoPath) async {
    // 1. Remove from metadata box
    await _box.delete(photoPath);

    // 3. Delete physical file (if not web)
    if (!kIsWeb) {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> deletePhotos(Map<String, List<String>> photosByDate) async {
    for (final entry in photosByDate.entries) {
      final date = entry.key;
      for (final path in entry.value) {
        await deletePhoto(date, path);
      }
    }
  }
}
