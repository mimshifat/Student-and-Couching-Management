import 'package:sqflite/sqflite.dart' as sqflite;
import '../../domain/entities/student.dart';
import '../../domain/entities/student_summary.dart';
import '../../domain/repositories/student_repository.dart';
import '../models/student_model.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/date_utils.dart';

class StudentRepositoryImpl implements StudentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _tableName = 'students';

  @override
  Future<int> insertStudent(Student student) async {
    final db = await _dbHelper.database;
    final model = StudentModel.fromEntity(student);
    return await db.insert(_tableName, model.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  @override
  Future<int> updateStudent(Student student) async {
    final db = await _dbHelper.database;
    final model = StudentModel.fromEntity(student);
    return await db.update(
      _tableName,
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  @override
  Future<int> deleteStudent(int id) async {
    final db = await _dbHelper.database;
    final nowStr = DateUtilsHelper.formatForDb(DateTime.now());
    
    return await db.transaction((txn) async {
      // Soft delete the student
      final count = await txn.update(
        _tableName,
        {'deleted_at': nowStr},
        where: 'id = ?',
        whereArgs: [id],
      );
      
      // Deactivate their active enrollments to stop fee accrual
      await txn.update(
        'enrollments',
        {'leave_date': nowStr},
        where: 'student_id = ? AND leave_date IS NULL',
        whereArgs: [id],
      );
      
      return count;
    });
  }

  @override
  Future<Student?> getStudentById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return StudentModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<List<Student>> getAllStudents() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'deleted_at IS NULL',
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return StudentModel.fromMap(maps[i]);
    });
  }

  @override
  Future<List<Student>> searchStudents(String query) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: '(name LIKE ? OR phone LIKE ?) AND deleted_at IS NULL',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return StudentModel.fromMap(maps[i]);
    });
  }

  @override
  Future<List<StudentSummary>> getFilteredStudentSummaries({
    String? status,
    String? className,
    int? batchId,
    String? searchQuery,
  }) async {
    final db = await _dbHelper.database;
    final List<String> conditions = ['s.deleted_at IS NULL'];
    final List<Object?> args = [];

    if (className != null && className.isNotEmpty) {
      conditions.add('s.class_name = ?');
      args.add(className);
    }

    if (batchId != null) {
      conditions.add('''s.id IN (
        SELECT student_id FROM enrollments 
        WHERE batch_id = ? AND leave_date IS NULL
      )''');
      args.add(batchId);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('(s.name LIKE ? OR s.phone LIKE ?)');
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }

    // Status filter
    if (status != null && status != 'All') {
      if (status == 'New') {
        conditions.add('(SELECT COUNT(*) FROM enrollments e WHERE e.student_id = s.id) = 0');
      } else if (status == 'Running') {
        conditions.add('(SELECT COUNT(*) FROM enrollments e WHERE e.student_id = s.id AND e.leave_date IS NULL) > 0');
      } else if (status == 'Previous') {
        conditions.add('''
          (SELECT COUNT(*) FROM enrollments e WHERE e.student_id = s.id) > 0 
          AND (SELECT COUNT(*) FROM enrollments e WHERE e.student_id = s.id AND e.leave_date IS NULL) = 0
        ''');
      }
    }

    final whereClause = conditions.join(' AND ');

    // Query with calculated status
    final String query = '''
      SELECT s.*, 
        CASE 
          WHEN (SELECT COUNT(*) FROM enrollments e WHERE e.student_id = s.id) = 0 THEN 'New'
          WHEN (SELECT COUNT(*) FROM enrollments e WHERE e.student_id = s.id AND e.leave_date IS NULL) > 0 THEN 'Running'
          ELSE 'Previous'
        END as calc_status
      FROM $_tableName s
      WHERE $whereClause
      ORDER BY s.name ASC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);

    return List.generate(maps.length, (i) {
      final student = StudentModel.fromMap(maps[i]);
      final calcStatus = maps[i]['calc_status'] as String;
      return StudentSummary(student: student, status: calcStatus);
    });
  }

  @override
  Future<List<Student>> getStudentsByBatch(int batchId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.* FROM students s
      INNER JOIN enrollments e ON s.id = e.student_id
      WHERE e.batch_id = ? AND s.deleted_at IS NULL AND e.leave_date IS NULL
      ORDER BY s.name ASC
    ''', [batchId]);

    return List.generate(maps.length, (i) {
      return StudentModel.fromMap(maps[i]);
    });
  }
}
