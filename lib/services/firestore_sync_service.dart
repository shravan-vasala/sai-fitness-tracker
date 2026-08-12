import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../interfaces/i_auth_service.dart';
import '../interfaces/i_cloud_sync_service.dart';

/// Handles all Firestore cloud sync operations.
///
/// Architecture:
///   - Hive remains the source-of-truth for reads (instant, offline).
///   - After every Hive write, repositories call [syncToCloud] which
///     fires a non-blocking Firestore write.
///   - On first sign-in, [migrateLocalToCloud] uploads all existing
///     Hive data to Firestore.
///   - On sign-in on a new device, [pullCollection] downloads cloud
///     data into Hive.
class FirestoreSyncService implements ICloudSyncService {
  final IAuthService _auth;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirestoreSyncService(this._auth);

  /// Whether syncing is available (user signed in).
  @override
  bool get canSync => _auth.isSignedIn;

  /// Reference to the current user's document.
  DocumentReference? get _userDoc {
    final uid = _auth.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  /// Reference to a sub-collection under the current user.
  CollectionReference? _subcollection(String name) {
    return _userDoc?.collection(name);
  }

  // ──────────────────────────────────────────────
  //  WRITE — fire-and-forget sync after Hive write
  // ──────────────────────────────────────────────

  /// Sync a single document to Firestore. Non-blocking.
  /// [collection] is the sub-collection name (e.g. 'daily_logs').
  /// [docId] is the document key (e.g. '2026-08-04').
  /// [data] is the JSON map to store.
  @override
  void syncToCloud(String collection, String docId, Map<String, dynamic> data) {
    if (!canSync) return;

    final ref = _subcollection(collection);
    if (ref == null) return;

    // Fire-and-forget — don't await, don't block UI
    ref.doc(docId).set(data, SetOptions(merge: true)).catchError((e) {
      debugPrint('FirestoreSync: Error syncing $collection/$docId: $e');
    });
  }

  /// Delete a document from Firestore. Non-blocking.
  @override
  void deleteFromCloud(String collection, String docId) {
    if (!canSync) return;

    final ref = _subcollection(collection);
    if (ref == null) return;

    ref.doc(docId).delete().catchError((e) {
      debugPrint('FirestoreSync: Error deleting $collection/$docId: $e');
    });
  }

  /// Sync the user profile (stored as a single doc, not a sub-collection).
  @override
  void syncProfile(Map<String, dynamic> data) {
    if (!canSync) return;

    final doc = _userDoc;
    if (doc == null) return;

    doc.set({
      'profile': data,
      'lastSyncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((e) {
      debugPrint('FirestoreSync: Error syncing profile: $e');
    });
  }

  // ──────────────────────────────────────────────
  //  READ — pull cloud data on sign-in
  // ──────────────────────────────────────────────

  /// Fetches an entire sub-collection and formats it as a Hive-ready map.
  @override
  Future<Map<String, Map<String, dynamic>>> pullCollection(
      String collection) async {
    if (!canSync) return {};

    final ref = _subcollection(collection);
    if (ref == null) return {};

    try {
      final snapshot = await ref.get();
      final result = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        result[doc.id] = doc.data() as Map<String, dynamic>;
      }
      debugPrint(
          'FirestoreSync: Pulled ${result.length} docs from $collection');
      return result;
    } catch (e) {
      debugPrint('FirestoreSync: Error pulling $collection: $e');
      return {};
    }
  }
  /// Pull all documents from a global Firestore collection (not user-specific).
  /// Used for pulling global workout/meal plans.
  @override
  Future<Map<String, Map<String, dynamic>>> pullGlobalCollection(
      String collection) async {
    try {
      final snapshot = await _db.collection(collection).get();
      final result = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        result[doc.id] = doc.data();
      }
      debugPrint(
          'FirestoreSync: Pulled ${result.length} docs from global $collection');
      return result;
    } catch (e) {
      debugPrint('FirestoreSync: Error pulling global $collection: $e');
      return {};
    }
  }


  /// Fetches the user profile from the cloud.
  @override
  Future<Map<String, dynamic>?> pullProfile() async {
    if (!canSync) return null;

    final doc = _userDoc;
    if (doc == null) return null;

    try {
      final snapshot = await doc.get();
      if (!snapshot.exists) return null;
      final data = snapshot.data() as Map<String, dynamic>?;
      return data?['profile'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('FirestoreSync: Error pulling profile: $e');
      return null;
    }
  }

  /// Checks if the user has any data backed up in the cloud.
  @override
  Future<bool> hasCloudData() async {
    if (!canSync) return false;

    final doc = _userDoc;
    if (doc == null) return false;

    try {
      final snapshot = await doc.get();
      return snapshot.exists;
    } catch (e) {
      debugPrint('FirestoreSync: Error checking cloud data: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────
  //  BULK MIGRATION — local Hive → Firestore
  // ──────────────────────────────────────────────

  /// Upload a batch of documents to a Firestore sub-collection.
  /// Used during initial migration of local data to cloud.
  @override
  Future<void> bulkSync(
      String collection, Map<String, Map<String, dynamic>> docs) async {
    if (!canSync || docs.isEmpty) return;

    final ref = _subcollection(collection);
    if (ref == null) return;

    try {
      // Use batched writes for efficiency (max 500 per batch)
      final entries = docs.entries.toList();
      for (int i = 0; i < entries.length; i += 500) {
        final batch = _db.batch();
        final chunk = entries.skip(i).take(500);
        for (final entry in chunk) {
          batch.set(ref.doc(entry.key), entry.value, SetOptions(merge: true));
        }
        await batch.commit();
      }
      debugPrint(
          'FirestoreSync: Bulk synced ${docs.length} docs to $collection');
    } catch (e) {
      debugPrint('FirestoreSync: Error bulk syncing $collection: $e');
    }
  }
}
