import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:student_management/core/database/database_helper.dart';
import 'package:student_management/core/sync/sync_schema.dart';
import 'package:student_management/core/sync/sync_tables.dart';

import 'v22_fixture.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper().closeDatabase();
    tempDir = await Directory.systemTemp.createTemp('sync_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
    dbPath = p.join(tempDir.path, 'coaching_app.db');
  });

  tearDown(() async {
    await DatabaseHelper().closeDatabase();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> createV22Db() async {
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 22,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await createV22Schema(db);
          await seedV22Data(db);
        },
      ),
    );
    await db.close();
  }

  Future<int> count(Database db, String table, [String where = '1=1']) async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM $table WHERE $where');
    return r.first['c'] as int;
  }

  Future<String?> sid(Database db, String table, int id) async {
    final r = await db.query('sync_map', where: 'tbl = ? AND local_id = ?', whereArgs: [table, id]);
    return r.isEmpty ? null : r.first['sync_id'] as String;
  }

  Future<Map<String, Object?>?> outbox(Database db, String table, String syncId) async {
    final r = await db.query('sync_outbox', where: 'tbl = ? AND sync_id = ?', whereArgs: [table, syncId]);
    return r.isEmpty ? null : r.first;
  }

  group('v22 -> v23 upgrade (existing users)', () {
    test('keeps every row, maps every row, enqueues nothing, keeps a safety copy', () async {
      await createV22Db();
      final before = <String, int>{};
      {
        final db = await databaseFactory.openDatabase(dbPath, options: OpenDatabaseOptions(readOnly: true));
        for (final t in SyncTables.all) {
          before[t.name] = await count(db, t.name);
        }
        await db.close();
      }

      final db = await DatabaseHelper().database;
      expect(await db.getVersion(), 23);

      for (final t in SyncTables.all) {
        expect(await count(db, t.name), before[t.name], reason: 'row count of ${t.name}');
        expect(await count(db, 'sync_map', "tbl = '${t.name}'"), before[t.name],
            reason: 'every ${t.name} row has a sync_id');
      }
      expect(await count(db, 'sync_outbox'), 0, reason: 'nothing is uploaded before login');
      expect(File('$dbPath.v22.bak').existsSync(), isTrue, reason: 'safety copy of old db');

      final dev = await db.query('sync_meta', where: "key = 'device_id'");
      expect(dev.single['value'], matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));

      // sync ids are globally unique per table
      final dup = await db.rawQuery('SELECT tbl, sync_id, COUNT(*) c FROM sync_map GROUP BY tbl, sync_id HAVING c > 1');
      expect(dup, isEmpty);
    });

    test('deterministic ids for results and fee_records, legacy duplicates get random ids', () async {
      await createV22Db();
      final db = await DatabaseHelper().database;
      final exam = await sid(db, 'exams', 1);
      final s1 = await sid(db, 'students', 1);
      final s2 = await sid(db, 'students', 2);
      final b1 = await sid(db, 'batches', 1);

      expect(await sid(db, 'results', 1), 'rs_${exam}_$s1');
      expect(await sid(db, 'results', 2), 'rs_${exam}_$s2');
      expect(await sid(db, 'fee_records', 1), 'fr_${s1}_${b1}_2026_1');
      expect(await sid(db, 'fee_records', 2), 'fr_${s1}_${b1}_2026_2');
      // id 3 is a legacy duplicate of id 1 -> random uuid, no crash
      expect(await sid(db, 'fee_records', 3), isNot(startsWith('fr_')));
      // legacy record without batch
      expect(await sid(db, 'fee_records', 4), 'fr_${s2}_none_2025_12');
    });
  });

  group('change capture triggers', () {
    test('insert / update / delete are captured and coalesced per record', () async {
      final db = await DatabaseHelper().database; // fresh install path
      final id = await db.insert('notes', {'title': 'a', 'content': 'b', 'created_at': 'x', 'updated_at': 'x'});
      final s = (await sid(db, 'notes', id))!;
      var o = (await outbox(db, 'notes', s))!;
      expect(o['op'], 'upsert');
      expect(o['version'], 1);

      await db.update('notes', {'title': 'a2'}, where: 'id = ?', whereArgs: [id]);
      await db.update('notes', {'title': 'a3'}, where: 'id = ?', whereArgs: [id]);
      o = (await outbox(db, 'notes', s))!;
      expect(o['version'], 3, reason: 'one outbox row, version bumped');
      expect(await count(db, 'sync_outbox'), 1);

      await db.delete('notes', where: 'id = ?', whereArgs: [id]);
      o = (await outbox(db, 'notes', s))!;
      expect(o['op'], 'delete', reason: 'tombstone keeps the sync_id');
      expect(await sid(db, 'notes', id), isNull, reason: 'mapping released');
    });

    test('results delete + re-insert (exam save) keeps the same cloud id', () async {
      await createV22Db();
      final db = await DatabaseHelper().database;
      final before = await sid(db, 'results', 1);

      await db.transaction((txn) async {
        await txn.delete('results', where: 'exam_id = ?', whereArgs: [1]);
        await txn.insert('results', {'exam_id': 1, 'student_id': 1, 'batch_id': 1, 'obtained_marks': 95.0, 'created_at': 'x'});
      });
      final newRow = await db.query('results', where: 'student_id = 1');
      final newId = newRow.single['id'] as int;
      expect(await sid(db, 'results', newId), before);
      final o = (await outbox(db, 'results', before!))!;
      expect(o['op'], 'upsert');
      expect(o['local_id'], newId);
    });

    test('FK cascade deletes are captured', () async {
      await createV22Db();
      final db = await DatabaseHelper().database;
      final r1 = await sid(db, 'results', 1);
      await db.delete('exams', where: 'id = ?', whereArgs: [1]);
      expect((await outbox(db, 'results', r1!))?['op'], 'delete');
    });

    test('remote apply does not echo back but still maps ids', () async {
      final db = await DatabaseHelper().database;
      await db.insert('sync_meta', {'key': SyncSchema.metaApplyingRemote, 'value': '1'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('sync_map', {'tbl': 'students', 'local_id': 500, 'sync_id': 'remote-sid'});
      await db.insert('students', {'id': 500, 'name': 'R', 'created_at': 'x', 'updated_at': 'x'});
      expect(await sid(db, 'students', 500), 'remote-sid');
      expect(await count(db, 'sync_outbox'), 0);
    });

    test('replace-insert with an existing id keeps the sync id', () async {
      final db = await DatabaseHelper().database;
      await db.insert('students', {'id': 7, 'name': 'A', 'created_at': 'x', 'updated_at': 'x'});
      final s = await sid(db, 'students', 7);
      await db.insert('students', {'id': 7, 'name': 'B', 'created_at': 'x', 'updated_at': 'x'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      expect(await sid(db, 'students', 7), s);
    });
  });

  group('write guard', () {
    test('blocks all data writes when the session was replaced', () async {
      final db = await DatabaseHelper().database;
      final id = await db.insert('notes', {'title': 'a', 'content': 'b', 'created_at': 'x', 'updated_at': 'x'});
      await db.update('sync_meta', {'value': SyncSchema.sessionReplaced}, where: "key = 'session_state'");

      expect(() => db.insert('notes', {'title': 'c', 'content': 'd', 'created_at': 'x', 'updated_at': 'x'}),
          throwsA(predicate((e) => e.toString().contains(SyncSchema.sessionReplacedError))));
      expect(() => db.update('notes', {'title': 'z'}, where: 'id = ?', whereArgs: [id]),
          throwsA(isA<DatabaseException>()));
      expect(() => db.delete('notes', where: 'id = ?', whereArgs: [id]), throwsA(isA<DatabaseException>()));
      expect(await count(db, 'notes'), 1);
    });
  });

  test('enqueueAll queues every existing row exactly once', () async {
    await createV22Db();
    final db = await DatabaseHelper().database;
    final total = await count(db, 'sync_map');
    expect(await SyncSchema.enqueueAll(db), total);
    expect(await SyncSchema.enqueueAll(db), total, reason: 'idempotent');
  });

  test('install is idempotent (re-run on an already migrated db)', () async {
    await createV22Db();
    final db = await DatabaseHelper().database;
    final before = await db.query('sync_map', orderBy: 'tbl, local_id');
    await SyncSchema.install(db);
    expect(await db.query('sync_map', orderBy: 'tbl, local_id'), before);
  });
}
