import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/database_helper.dart';
import 'sync_meta_store.dart';

class SessionManager {
  static const String _keyOwnerUid = 'owner_uid';

  final SyncMetaStore _metaStore;
  
  SessionManager({SyncMetaStore? metaStore}) 
      : _metaStore = metaStore ?? SyncMetaStore(dbHelper: DatabaseHelper());

  /// Returns the UID of the user who owns the local database.
  /// If null, the database is unassigned (e.g., an old app before login).
  Future<String?> getOwnerUid() async {
    return await _metaStore.get(_keyOwnerUid);
  }

  /// Binds the local database to a user account.
  /// If the database was unassigned, it now belongs to [uid].
  /// If the database was already assigned to a different [uid], it throws an error.
  Future<void> bindAccount(String uid) async {
    final currentOwner = await getOwnerUid();
    
    if (currentOwner == null) {
      // First login! The existing offline data (or empty DB) is now owned by this user.
      await _metaStore.set(_keyOwnerUid, uid);
    } else if (currentOwner != uid) {
      // Security measure: someone else logged in on this phone.
      throw Exception('This device contains data belonging to another account. Please clear app data first.');
    }
  }

  /// Claims the active session in Firestore for this device.
  Future<void> claimSession(String uid) async {
    final deviceId = await _metaStore.get('device_id') ?? 'unknown';
    
    // Initialize user document so admin can manage status easily in the console
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      // First time this user has ever logged in, create the document with default active status
      await userRef.set({
        'status': 'active',
        'email': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        'last_active': FieldValue.serverTimestamp(),
      });
    } else {
      // User already exists, just update their last active time without touching their status
      await userRef.update({
        'last_active': FieldValue.serverTimestamp(),
      });
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('session')
        .set({
      'device_id': deviceId,
      'claimed_at': FieldValue.serverTimestamp(),
    });
    await _metaStore.set('session_state', 'active');
  }

  /// Watches the user's status document to detect suspension/deactivation.
  Stream<String> watchUserStatus(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return 'active';
      return snapshot.data()?['status'] as String? ?? 'active';
    });
  }

  /// Starts listening to the Firestore session claim. 
  /// If another device claims the session, this device enters a read-only state.
  Stream<bool> watchSessionLock(String uid) async* {
    final localDeviceId = await _metaStore.get('device_id') ?? 'unknown';
    
    yield* FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('session')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return false;
      
      final activeDeviceId = snapshot.data()?['device_id'] as String?;
      final isLocked = activeDeviceId != null && activeDeviceId != localDeviceId;
      
      // Update local sqlite so triggers block writes
      _metaStore.set(
        'session_state', 
        isLocked ? 'replaced' : 'active'
      );
      
      return isLocked;
    });
  }
}
