import 'package:sqflite/sqflite.dart';

import 'sync_tables.dart';

/// Installs and maintains the local sync infrastructure inside the existing
/// SQLite database (added in DB version 23).
///
/// Design notes:
/// * Existing tables are NOT altered. A separate `sync_map` table links every
///   row `(tbl, local_id)` to a global `sync_id` (the Firestore document id).
///   This keeps all existing models / repositories untouched and survives
///   `ConflictAlgorithm.replace` inserts.
/// * Triggers capture every insert/update/delete, including FK cascades and
///   every current or future repository code path, into `sync_outbox`.
/// * The outbox is coalesced per record: one row per `(tbl, sync_id)` with a
///   `version` counter that increases on every change. The uploader (Phase 3)
///   only removes an outbox row when the version it uploaded is still current,
///   so an edit made during an upload is never lost.
/// * A write-guard blocks all data writes once the session has been replaced
///   by another device (enforced in the DB, not only in the UI).
/// * Only SQL supported by SQLite 3.8 (Android 5+) is used (no UPSERT syntax).
class SyncSchema {
  SyncSchema._();

  /// Meta keys stored in `sync_meta`.
  static const String metaOwnerUid = 'owner_uid';
  static const String metaOwnerEmail = 'owner_email';
  static const String metaDeviceId = 'device_id';
  static const String metaSessionState = 'session_state';
  static const String metaApplyingRemote = 'applying_remote';
  static const String metaNeedsBootstrap = 'needs_bootstrap';
  static const String metaBoundAt = 'bound_at';

  /// Possible values of [metaSessionState].
  static const String sessionActive = 'active';
  static const String sessionReplaced = 'replaced';

  /// Error text raised by the write-guard trigger.
  static const String sessionReplacedError = 'SESSION_REPLACED';

  /// SQL expression producing a random RFC-4122 v4 UUID.
  static const String uuidSql =
      "(lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || "
      "substr(lower(hex(randomblob(2))), 2) || '-' || "
      "substr('89ab', 1 + (abs(random()) % 4), 1) || "
      "substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6))))";

  static const String _nowSql = "strftime('%Y-%m-%dT%H:%M:%fZ', 'now')";

  /// True unless remote data is currently being applied (restore / pull).
  static const String _trackingSql =
      "(SELECT value FROM sync_meta WHERE key = '$metaApplyingRemote') IS NOT '1'";

  /// Idempotent: safe to call on fresh installs, upgrades and imported files.
  static Future<void> install(DatabaseExecutor db) async {
    await _createTables(db);
    await _backfillSyncIds(db);
    await _createTriggers(db);
    // Stable per-install device id (used for single-active-device sessions).
    await db.execute(
      "INSERT OR IGNORE INTO sync_meta(key, value) VALUES ('$metaDeviceId', $uuidSql)",
    );
    await db.execute(
      "INSERT OR IGNORE INTO sync_meta(key, value) VALUES ('$metaSessionState', '$sessionActive')",
    );
    // A crash during a remote apply must never leave tracking disabled.
    await db.execute("DELETE FROM sync_meta WHERE key = '$metaApplyingRemote'");
  }

  static Future<void> _createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_map (
        tbl TEXT NOT NULL,
        local_id INTEGER NOT NULL,
        sync_id TEXT NOT NULL,
        PRIMARY KEY (tbl, local_id)
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_map_sid ON sync_map(tbl, sync_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        tbl TEXT NOT NULL,
        sync_id TEXT NOT NULL,
        local_id INTEGER NOT NULL,
        op TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        changed_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        PRIMARY KEY (tbl, sync_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_changed ON sync_outbox(changed_at)',
    );

    // Hash of the last successfully uploaded content per record. Lets the
    // uploader skip writes when nothing really changed (saves Firestore quota).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_hash (
        tbl TEXT NOT NULL,
        sync_id TEXT NOT NULL,
        hash TEXT NOT NULL,
        pushed_at TEXT NOT NULL,
        PRIMARY KEY (tbl, sync_id)
      )
    ''');

    // Changes the server permanently refused. Kept forever until the user
    // exports/discards them explicitly — pending data is never silently lost.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_quarantine (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tbl TEXT NOT NULL,
        sync_id TEXT NOT NULL,
        op TEXT NOT NULL,
        payload TEXT,
        reason TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Gives every existing row a sync_id (parents first, so deterministic ids
  /// of children can reference them). Does NOT enqueue anything: the initial
  /// upload is triggered explicitly when the database is bound to an account.
  static Future<void> _backfillSyncIds(DatabaseExecutor db) async {
    for (final t in SyncTables.all) {
      final det = t.deterministicIdFor('t');
      if (det != null) {
        await db.execute(
          "INSERT OR IGNORE INTO sync_map(tbl, local_id, sync_id) "
          "SELECT '${t.name}', t.id, $det FROM ${t.name} t ORDER BY t.id",
        );
      }
      // Random id for everything else (and for duplicate legacy rows whose
      // deterministic id was already taken by an older row).
      await db.execute(
        "INSERT OR IGNORE INTO sync_map(tbl, local_id, sync_id) "
        "SELECT '${t.name}', t.id, $uuidSql FROM ${t.name} t",
      );
    }
  }

  static Future<void> _createTriggers(DatabaseExecutor db) async {
    for (final t in SyncTables.all) {
      for (final stmt in triggerStatements(t)) {
        await db.execute(stmt);
      }
    }
  }

  /// SQL to (re)create all triggers of one table.
  static List<String> triggerStatements(SyncTableSpec t) {
    final n = t.name;
    final guardWhen =
        "(SELECT value FROM sync_meta WHERE key = '$metaSessionState') = '$sessionReplaced' AND $_trackingSql";

    String ensureMap(String ref) {
      final det = t.deterministicIdFor(ref);
      final buf = StringBuffer();
      if (det != null) {
        buf.writeln(
          "  INSERT OR IGNORE INTO sync_map(tbl, local_id, sync_id) VALUES ('$n', $ref.id, $det);",
        );
      }
      buf.writeln(
        "  INSERT OR IGNORE INTO sync_map(tbl, local_id, sync_id) VALUES ('$n', $ref.id, $uuidSql);",
      );
      return buf.toString();
    }

    String enqueue(String ref, String op) {
      final sid = "(SELECT sync_id FROM sync_map WHERE tbl = '$n' AND local_id = $ref.id)";
      return '''
  UPDATE sync_outbox
     SET op = '$op', local_id = $ref.id, version = version + 1,
         changed_at = $_nowSql, attempts = 0, last_error = NULL
   WHERE tbl = '$n' AND sync_id = $sid AND $_trackingSql;
  INSERT OR IGNORE INTO sync_outbox(tbl, sync_id, local_id, op, version, changed_at)
    SELECT '$n', sync_id, $ref.id, '$op', 1, $_nowSql
      FROM sync_map WHERE tbl = '$n' AND local_id = $ref.id AND $_trackingSql;
''';
    }

    return [
      // ---- write guard (session replaced by another device) ----
      'DROP TRIGGER IF EXISTS sync_guard_bi_$n',
      '''
CREATE TRIGGER sync_guard_bi_$n BEFORE INSERT ON $n WHEN $guardWhen
BEGIN
  SELECT RAISE(ABORT, '$sessionReplacedError');
END''',
      'DROP TRIGGER IF EXISTS sync_guard_bu_$n',
      '''
CREATE TRIGGER sync_guard_bu_$n BEFORE UPDATE ON $n WHEN $guardWhen
BEGIN
  SELECT RAISE(ABORT, '$sessionReplacedError');
END''',
      'DROP TRIGGER IF EXISTS sync_guard_bd_$n',
      '''
CREATE TRIGGER sync_guard_bd_$n BEFORE DELETE ON $n WHEN $guardWhen
BEGIN
  SELECT RAISE(ABORT, '$sessionReplacedError');
END''',

      // ---- change capture ----
      'DROP TRIGGER IF EXISTS sync_ai_$n',
      '''
CREATE TRIGGER sync_ai_$n AFTER INSERT ON $n
BEGIN
${ensureMap('NEW')}${enqueue('NEW', 'upsert')}END''',
      'DROP TRIGGER IF EXISTS sync_au_$n',
      '''
CREATE TRIGGER sync_au_$n AFTER UPDATE ON $n
BEGIN
${ensureMap('NEW')}${enqueue('NEW', 'upsert')}END''',
      'DROP TRIGGER IF EXISTS sync_ad_$n',
      '''
CREATE TRIGGER sync_ad_$n AFTER DELETE ON $n
BEGIN
${enqueue('OLD', 'delete')}  DELETE FROM sync_map WHERE tbl = '$n' AND local_id = OLD.id;
END''',
    ];
  }

  /// Queues every existing row for upload (initial upload after the local
  /// database is bound to an account). Already-queued rows are left as-is.
  static Future<int> enqueueAll(DatabaseExecutor db) async {
    for (final t in SyncTables.all) {
      await db.execute(
        "INSERT OR IGNORE INTO sync_outbox(tbl, sync_id, local_id, op, version, changed_at) "
        "SELECT m.tbl, m.sync_id, m.local_id, 'upsert', 1, $_nowSql "
        "FROM sync_map m JOIN ${t.name} r ON r.id = m.local_id WHERE m.tbl = '${t.name}'",
      );
    }
    return pendingCount(db);
  }

  /// Number of records waiting to be uploaded.
  static Future<int> pendingCount(DatabaseExecutor db) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM sync_outbox');
    return (rows.first['c'] as int?) ?? 0;
  }
}
