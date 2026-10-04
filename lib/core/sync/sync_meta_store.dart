import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'sync_schema.dart';

/// Typed access to the `sync_meta` key/value table.
class SyncMetaStore {
  SyncMetaStore({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper();

  final DatabaseHelper _dbHelper;

  Future<String?> get(String key, {DatabaseExecutor? txn}) async {
    final db = txn ?? await _dbHelper.database;
    final rows = await db.query('sync_meta', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String? value, {DatabaseExecutor? txn}) async {
    final db = txn ?? await _dbHelper.database;
    if (value == null) {
      await db.delete('sync_meta', where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert(
        'sync_meta',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<String?> ownerUid() => get(SyncSchema.metaOwnerUid);
  Future<String?> ownerEmail() => get(SyncSchema.metaOwnerEmail);
  Future<String?> deviceId() => get(SyncSchema.metaDeviceId);

  Future<bool> isSessionReplaced() async =>
      (await get(SyncSchema.metaSessionState)) == SyncSchema.sessionReplaced;

  Future<int> pendingCount() async => SyncSchema.pendingCount(await _dbHelper.database);

  /// True if the local database holds any user data at all.
  Future<bool> hasLocalData() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM sync_map');
    return ((rows.first['c'] as int?) ?? 0) > 0;
  }
}
