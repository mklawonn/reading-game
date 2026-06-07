import 'package:cloud_firestore/cloud_firestore.dart';

import 'progress_store.dart';

/// Firestore-backed persistence, scoped exactly per the security rules in
/// `backend/firestore.rules`:
///
///   /parents/{uid}/children/{profileId}/state/progress
///
/// Active once Firebase is configured and a parent is signed in (the [uid]
/// comes from Firebase Auth). Until then the app uses [LocalProgressStore].
class FirestoreProgressStore implements ProgressStore {
  FirestoreProgressStore({required this.uid, FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String profileId) => _db
      .collection('parents')
      .doc(uid)
      .collection('children')
      .doc(profileId)
      .collection('state')
      .doc('progress');

  @override
  Future<Map<String, dynamic>?> load(String profileId) async {
    final snap = await _doc(profileId).get();
    return snap.data();
  }

  @override
  Future<void> save(String profileId, Map<String, dynamic> data) async {
    await _doc(profileId).set(data, SetOptions(merge: true));
  }
}
