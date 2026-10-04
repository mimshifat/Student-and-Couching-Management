import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import 'session_manager.dart';
import 'sync_mapper.dart';
import 'sync_tables.dart';
import 'sync_schema.dart';

class SyncRestore {
  final DatabaseHelper _dbHelper;
  final SessionManager _sessionManager;
  final FirebaseFirestore _firestore;

  SyncRestore({
    DatabaseHelper? dbHelper,
    SessionManager? sessionManager,
    FirebaseFirestore? firestore,
  })  : _dbHelper = dbHelper ?? DatabaseHelper(),
        _sessionManager = sessionManager ?? SessionManager(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Restores all data from Firestore into the local SQLite database.
  /// Used during initial setup or when forcing a resync.
  Future<void> restoreFromCloud() async {
    final uid = await _sessionManager.getOwnerUid();
    if (uid == null) throw Exception("Cannot restore: no bound user account.");

    final db = await _dbHelper.database;
    
    // 1. Claim session (so other devices stop writing)
    final deviceIdResult = await db.rawQuery("SELECT value FROM sync_meta WHERE key = 'device_id'");
    final deviceId = deviceIdResult.isNotEmpty ? deviceIdResult.first['value'] as String : 'unknown';
    
    await _firestore.collection('users').doc(uid).collection('meta').doc('session').set({
      'device_id': deviceId,
      'claimed_at': FieldValue.serverTimestamp(),
    });

    // 2. Set applying_remote flag to disable triggers
    await db.rawInsert("INSERT OR REPLACE INTO sync_meta(key, value) VALUES ('${SyncSchema.metaApplyingRemote}', '1')");

    try {
      // 3. Clear existing local data (since we are doing a full restore)
      // Must delete in reverse foreign-key order to avoid constraint errors
      for (final tableSpec in SyncTables.all.reversed) {
        await db.delete(tableSpec.name);
      }
      await db.delete('sync_map');
      await db.delete('sync_outbox');
      await db.delete('sync_hash');

      // 4. Download and insert in forward foreign-key order
      for (final tableSpec in SyncTables.all) {
        final snapshot = await _firestore.collection('users').doc(uid).collection(tableSpec.name).get();
        
        final batch = db.batch();
        
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data['_deleted'] == true) continue; // Skip tombstones

          // Map Firestore string references back to SQLite local_id references
          final localRow = await SyncMapper.fromFirestore(db, tableSpec.name, data);
          
          // Insert the data and capture the new local auto-increment ID
          final localId = await db.insert(tableSpec.name, localRow);
          
          // Re-establish the sync_map link
          batch.rawInsert(
            "INSERT INTO sync_map(tbl, local_id, sync_id) VALUES (?, ?, ?)",
            [tableSpec.name, localId, doc.id]
          );
        }
        
        await batch.commit(noResult: true);
      }

      // 5. Recompute dependent data
      await _recomputeFeePaidAmounts(db);
      
      // Update session state
      await db.rawInsert("INSERT OR REPLACE INTO sync_meta(key, value) VALUES ('${SyncSchema.metaSessionState}', '${SyncSchema.sessionActive}')");

    } finally {
      // 6. Unset applying_remote flag to re-enable triggers
      await db.rawDelete("DELETE FROM sync_meta WHERE key = '${SyncSchema.metaApplyingRemote}'");
    }
  }

  Future<void> _recomputeFeePaidAmounts(Database db) async {
    // Recalculate paid_amount for all fee_records based on fee_transactions
    final rows = await db.rawQuery('''
      SELECT fee_record_id, SUM(amount) as total_paid 
      FROM fee_transactions 
      GROUP BY fee_record_id
    ''');
    
    final batch = db.batch();
    for (final row in rows) {
      batch.update(
        'fee_records',
        {'paid_amount': row['total_paid']},
        where: 'id = ?',
        whereArgs: [row['fee_record_id']]
      );
    }
    await batch.commit(noResult: true);
  }
}
