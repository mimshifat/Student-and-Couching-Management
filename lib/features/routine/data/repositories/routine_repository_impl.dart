import 'package:sqflite/sqflite.dart' as sqflite;
import '../../domain/entities/routine.dart';
import '../../domain/repositories/routine_repository.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/date_utils.dart';

class RoutineModel extends Routine {
  RoutineModel({
    super.id,
    required super.batchId,
    required super.dayOfWeek,
    required super.startTime,
    required super.endTime,
    required super.subject,
    super.teacherName,
    required super.createdAt,
  });

  factory RoutineModel.fromEntity(Routine entity) {
    return RoutineModel(
      id: entity.id,
      batchId: entity.batchId,
      dayOfWeek: entity.dayOfWeek,
      startTime: entity.startTime,
      endTime: entity.endTime,
      subject: entity.subject,
      teacherName: entity.teacherName,
      createdAt: entity.createdAt,
    );
  }

  factory RoutineModel.fromMap(Map<String, dynamic> map) {
    return RoutineModel(
      id: map['id'],
      batchId: map['batch_id'],
      dayOfWeek: map['day_of_week'],
      startTime: map['start_time'],
      endTime: map['end_time'],
      subject: map['subject'],
      teacherName: map['teacher_name'],
      createdAt: DateUtilsHelper.parseFromDb(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batch_id': batchId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'subject': subject,
      'teacher_name': teacherName,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
    };
  }
}

class RoutineRepositoryImpl implements RoutineRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _table = 'routines';

  @override
  Future<int> insertRoutine(Routine routine) async {
    final db = await _dbHelper.database;
    final model = RoutineModel.fromEntity(routine);
    return await db.insert(_table, model.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  @override
  Future<int> deleteRoutine(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Routine>> getRoutinesByBatch(int batchId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(_table, where: 'batch_id = ?', whereArgs: [batchId], orderBy: 'start_time ASC');
    return List.generate(maps.length, (i) => RoutineModel.fromMap(maps[i]));
  }

  @override
  Future<List<Routine>> getRoutinesByDay(String dayOfWeek) async {
    final db = await _dbHelper.database;
    final maps = await db.query(_table, where: 'day_of_week = ?', whereArgs: [dayOfWeek], orderBy: 'start_time ASC');
    return List.generate(maps.length, (i) => RoutineModel.fromMap(maps[i]));
  }
}
