import 'package:sqflite/sqflite.dart';
import 'sync_tables.dart';

class SyncMapper {
  /// Converts a local SQLite row to a Firestore document map.
  /// Replaces local integer foreign keys with global string sync_ids.
  /// Removes the local `id` field.
  static Future<Map<String, dynamic>> toFirestore(
    DatabaseExecutor db,
    String table,
    Map<String, dynamic> localRow,
  ) async {
    final spec = SyncTables.byName(table);
    final doc = Map<String, dynamic>.from(localRow);
    
    // Remove local auto-increment ID
    doc.remove('id');

    // Resolve foreign keys to sync_ids
    for (final parent in spec.parents) {
      final localFk = doc[parent.column];
      if (localFk != null && localFk is int) {
        final result = await db.rawQuery(
          "SELECT sync_id FROM sync_map WHERE tbl = ? AND local_id = ?",
          [parent.parentTable, localFk],
        );
        if (result.isNotEmpty) {
          doc[parent.column] = result.first['sync_id'] as String;
        } else {
          // Parent might be missing/deleted, or sync_map broken.
          // In a perfect system this shouldn't happen due to FK constraints
          // and proper trigger ordering, but just in case:
          doc[parent.column] = null;
        }
      }
    }

    return doc;
  }

  /// Converts a Firestore document map back to a local SQLite row.
  /// Resolves string sync_ids to local integer IDs.
  static Future<Map<String, dynamic>> fromFirestore(
    DatabaseExecutor db,
    String table,
    Map<String, dynamic> remoteDoc,
  ) async {
    final spec = SyncTables.byName(table);
    final row = Map<String, dynamic>.from(remoteDoc);

    // Resolve foreign keys back to local IDs
    for (final parent in spec.parents) {
      final remoteFk = row[parent.column];
      if (remoteFk != null && remoteFk is String) {
        final result = await db.rawQuery(
          "SELECT local_id FROM sync_map WHERE tbl = ? AND sync_id = ?",
          [parent.parentTable, remoteFk],
        );
        if (result.isNotEmpty) {
          row[parent.column] = result.first['local_id'] as int;
        } else {
          // If a parent is missing locally during a restore, we might have an issue.
          // The restore process must insert parents before children (which SyncTables order guarantees).
          row[parent.column] = null;
        }
      }
    }

    return row;
  }
}
