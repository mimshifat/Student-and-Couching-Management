import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import 'session_manager.dart';
import 'sync_mapper.dart';

class SyncEngine {
  final DatabaseHelper _dbHelper;
  final SessionManager _sessionManager;
  final FirebaseFirestore _firestore;

  SyncEngine({
    DatabaseHelper? dbHelper,
    SessionManager? sessionManager,
    FirebaseFirestore? firestore,
  })  : _dbHelper = dbHelper ?? DatabaseHelper(),
        _sessionManager = sessionManager ?? SessionManager(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Runs the sync process. Uploads pending outbox records to Firestore.
  Future<void> runSync() async {
    final uid = await _sessionManager.getOwnerUid();
    if (uid == null) return; // Not logged in or bound

    final db = await _dbHelper.database;
    
    // Check if another device took over the session
    final sessionStateResult = await db.rawQuery(
      "SELECT value FROM sync_meta WHERE key = 'session_state'"
    );
    if (sessionStateResult.isNotEmpty && sessionStateResult.first['value'] == 'replaced') {
      return; // Stop uploading, we are locked out
    }

    bool hasMore = true;
    while (hasMore) {
      hasMore = await _processBatch(db, uid);
    }
  }

  Future<bool> _processBatch(Database db, String uid) async {
    // Read up to 500 rows ordered by changed_at
    final rows = await db.rawQuery(
      "SELECT * FROM sync_outbox WHERE attempts < 10 ORDER BY changed_at ASC LIMIT 500",
    );
    
    if (rows.isEmpty) return false;

    final batch = _firestore.batch();
    final processed = <Map<String, dynamic>>[];

    for (final row in rows) {
      final tbl = row['tbl'] as String;
      final syncId = row['sync_id'] as String;
      final localId = row['local_id'] as int;
      final op = row['op'] as String;

      final docRef = _firestore.collection('users').doc(uid).collection(tbl).doc(syncId);

      if (op == 'delete') {
        batch.set(
          docRef, 
          {
            '_deleted': true, 
            'deleted_at': FieldValue.serverTimestamp(),
          }, 
          SetOptions(merge: true)
        );
        processed.add(row);
      } else {
        // Upsert
        // Fetch current row from local table
        final localData = await db.query(tbl, where: 'id = ?', whereArgs: [localId]);
        if (localData.isNotEmpty) {
          final firestoreData = await SyncMapper.toFirestore(db, tbl, localData.first);
          batch.set(docRef, firestoreData, SetOptions(merge: true));
          processed.add(row);
        } else {
          // Row was deleted locally in the meantime. The trigger should have added a 'delete' op
          // to the outbox (or will shortly). We can skip this upsert safely.
          processed.add(row);
        }
      }
    }

    if (processed.isEmpty) {
      // Edge case: all rows were upserts but already missing locally
      // We still need to clean them up so we don't infinite loop.
      await _cleanupOutbox(db, rows);
      return true;
    }

    try {
      await batch.commit();
      await _cleanupOutbox(db, processed);
      return rows.length == 500;
    } on FirebaseException catch (e) {
      if (e.code == 'resource-exhausted') {
        // Quota exceeded. Stop syncing.
        return false;
      }
      
      // Increment attempts for these rows
      await _markErrors(db, processed, e.message ?? 'FirebaseException');
      // Stop syncing on other errors too to avoid hammering Firestore
      return false;
    } catch (e) {
      // General error
      await _markErrors(db, processed, e.toString());
      return false;
    }
  }

  Future<void> _markErrors(Database db, List<Map<String, dynamic>> processed, String error) async {
    final batchDb = db.batch();
    for (final p in processed) {
      batchDb.rawUpdate(
        "UPDATE sync_outbox SET attempts = attempts + 1, last_error = ? WHERE tbl = ? AND sync_id = ? AND version = ?",
        [error, p['tbl'], p['sync_id'], p['version']]
      );
    }
    await batchDb.commit(noResult: true);
  }

  Future<void> _cleanupOutbox(Database db, List<Map<String, dynamic>> processed) async {
    final batch = db.batch();
    for (final p in processed) {
      // Only delete if the version hasn't changed.
      // If version increased, it means the user edited it again while we were uploading.
      batch.rawDelete(
        "DELETE FROM sync_outbox WHERE tbl = ? AND sync_id = ? AND version = ?",
        [p['tbl'], p['sync_id'], p['version']]
      );
      
      // Update sync_hash (we don't calculate hash right now, just store timestamp)
      batch.rawInsert(
        "INSERT OR REPLACE INTO sync_hash(tbl, sync_id, hash, pushed_at) VALUES (?, ?, ?, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))",
        [p['tbl'], p['sync_id'], '']
      );
    }
    await batch.commit(noResult: true);
  }
}
