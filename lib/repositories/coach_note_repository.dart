import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/coach_note.dart';
import '../interfaces/i_cloud_sync_service.dart';

class CoachNoteRepository {
  static const String boxName = 'coach_notes_v2';
  late final Box<CoachNote> _box;
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) => _sync = sync;

  Future<void> init() async {
    _box = await Hive.openBox<CoachNote>(boxName);
  }

  CoachNote? getNote(String date) {
    return _box.get(date);
  }

  Future<void> saveNote(CoachNote note) async {
    await _box.put(note.date, note);
    _sync?.syncToCloud('coach_notes', note.date, note.toJson());
  }

  List<CoachNote> getRecentNotes(int limit) {
    final notes = _box.values.toList();
    notes.sort((a, b) => b.date.compareTo(a.date)); // Descending
    return notes.take(limit).toList();
  }

  // ── Cloud sync helpers ──

  Future<void> importNotesFromCloud(Map<String, Map<String, dynamic>> cloudData) async {
    for (final entry in cloudData.entries) {
      if (!_box.containsKey(entry.key)) {
        final note = CoachNote.fromJson(entry.value);
        await _box.put(entry.key, note);
      }
    }
  }

  Map<String, Map<String, dynamic>> exportNotesForCloud() {
    final result = <String, Map<String, dynamic>>{};
    for (final note in _box.values) {
      result[note.date] = note.toJson();
    }
    return result;
  }
}
