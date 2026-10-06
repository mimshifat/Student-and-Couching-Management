import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/entities/institute_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../models/institute_profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  Future<InstituteProfile?> getProfile() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('institute_profile');
    if (maps.isNotEmpty) {
      return InstituteProfileModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<void> saveProfile(InstituteProfile profile) async {
    final db = await _databaseHelper.database;
    final model = InstituteProfileModel.fromEntity(profile);
    
    final existing = await getProfile();
    if (existing != null) {
      // Update
      await db.update(
        'institute_profile',
        model.toMap(),
        where: 'id = ?',
        whereArgs: [1],
      );
    } else {
      // Insert
      await db.insert(
        'institute_profile',
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
