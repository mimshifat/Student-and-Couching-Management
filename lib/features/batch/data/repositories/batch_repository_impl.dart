import 'package:sqflite/sqflite.dart' as sqflite;
import '../../domain/entities/batch.dart';
import '../../domain/repositories/batch_repository.dart';
import '../models/batch_model.dart';
import '../../../../core/database/database_helper.dart';

class BatchRepositoryImpl implements BatchRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _tableName = 'batches';

  @override
  Future<int> insertBatch(Batch batch) async {
    final db = await _dbHelper.database;
    final model = BatchModel.fromEntity(batch);
    return await db.insert(_tableName, model.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  @override
  Future<int> updateBatch(Batch batch) async {
    final db = await _dbHelper.database;
    final model = BatchModel.fromEntity(batch);
    return await db.update(
      _tableName,
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  @override
  Future<int> deleteBatch(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<Batch?> getBatchById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return BatchModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<List<Batch>> getAllBatches() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return BatchModel.fromMap(maps[i]);
    });
  }
}
