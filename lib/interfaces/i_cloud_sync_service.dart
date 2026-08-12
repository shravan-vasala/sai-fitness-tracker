abstract class ICloudSyncService {
  bool get canSync;

  void syncToCloud(String collection, String docId, Map<String, dynamic> data);
  
  void deleteFromCloud(String collection, String docId);
  
  void syncProfile(Map<String, dynamic> data);
  
  Future<Map<String, Map<String, dynamic>>> pullCollection(String collection);
  
  Future<Map<String, Map<String, dynamic>>> pullGlobalCollection(String collection);
  
  Future<Map<String, dynamic>?> pullProfile();
  
  Future<bool> hasCloudData();
  
  Future<void> bulkSync(
    String collection,
    Map<String, Map<String, dynamic>> docs,
  );
}
