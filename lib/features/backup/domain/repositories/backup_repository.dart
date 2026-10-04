import 'dart:io';
import '../entities/backup_settings.dart';

abstract class BackupRepository {
  Future<BackupSettings> getSettings();
  Future<void> updateSettings(BackupSettings settings);
  
  Future<File> getDatabaseFile();
  Future<void> importDatabase(File file, {String? expectedUid});
  
  Future<bool> sendBackupToTelegram(BackupSettings settings);
}
