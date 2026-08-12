import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_profile.dart';
import '../interfaces/i_cloud_sync_service.dart';

class ProfileRepository {
  static const String _boxName = 'user_profile_v2';
  static const String _profileKey = 'profile';

  late Box<UserProfile> _box;
  final _secureStorage = const FlutterSecureStorage();
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) => _sync = sync;

  Future<void> init() async {
    _box = await Hive.openBox<UserProfile>(_boxName);
    if (!_box.containsKey(_profileKey)) {
      await saveProfile(UserProfile());
    }
  }

  Future<String?> getSecureGeminiKey() async {
    return await _secureStorage.read(key: 'gemini_api_key');
  }

  Future<void> saveSecureGeminiKey(String key) async {
    await _secureStorage.write(key: 'gemini_api_key', value: key);
  }

  UserProfile getProfile() {
    return _box.get(_profileKey) ?? UserProfile();
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _box.put(_profileKey, profile);
    _sync?.syncProfile(profile.toJson());
  }

  Future<void> updateName(String name) async {
    final profile = getProfile();
    await saveProfile(profile.copyWith(name: name));
  }

  Future<void> updateHeight(double height) async {
    final profile = getProfile();
    await saveProfile(profile.copyWith(height: height));
  }

  Future<void> updateTargetWeight(double weight) async {
    final profile = getProfile();
    await saveProfile(profile.copyWith(targetWeight: weight));
  }

  Future<void> toggleUnit() async {
    final profile = getProfile();
    await saveProfile(profile.copyWith(useKg: !profile.useKg));
  }

  // ── Cloud sync helpers ──

  Future<void> importProfileFromCloud(Map<String, dynamic>? cloudData) async {
    if (cloudData != null) {
      final profile = UserProfile.fromJson(cloudData);
      await _box.put(_profileKey, profile);
    }
  }

  Map<String, dynamic> exportProfileForCloud() {
    return getProfile().toJson();
  }
}
