import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/body_stats.dart';
import '../interfaces/i_cloud_sync_service.dart';

class BodyStatsRepository {
  static const String _boxName = 'body_stats_v2';

  late Box<BodyStats> _box;
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) => _sync = sync;

  Future<void> init() async {
    _box = await Hive.openBox<BodyStats>(_boxName);
  }

  BodyStats? getStats(String date) {
    return _box.get(date);
  }

  Future<void> saveStats(BodyStats stats) async {
    await _box.put(stats.date, stats);
    _sync?.syncToCloud('body_stats', stats.date, stats.toJson());
  }

  BodyStats? getLatestStats() {
    if (_box.isEmpty) return null;
    final keys = _box.keys.cast<String>().toList()..sort();
    return getStats(keys.last);
  }

  List<BodyStats> getAllStats() {
    final stats = _box.values.toList();
    stats.sort((a, b) => a.date.compareTo(b.date));
    return stats;
  }

  // ── Cloud sync helpers ──

  Future<void> importStatsFromCloud(Map<String, Map<String, dynamic>> cloudData) async {
    for (final entry in cloudData.entries) {
      if (!_box.containsKey(entry.key)) {
        final stats = BodyStats.fromJson(entry.value);
        await _box.put(entry.key, stats);
      }
    }
  }

  Map<String, Map<String, dynamic>> exportStatsForCloud() {
    final result = <String, Map<String, dynamic>>{};
    for (final stats in _box.values) {
      result[stats.date] = stats.toJson();
    }
    return result;
  }
}
