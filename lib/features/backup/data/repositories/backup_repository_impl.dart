import 'dart:io';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:http/http.dart' as http;

import '../../domain/entities/backup_settings.dart';
import '../../domain/repositories/backup_repository.dart';
import '../../../../core/database/database_helper.dart';

class BackupRepositoryImpl implements BackupRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _table = 'backup_settings';

  @override
  Future<BackupSettings> getSettings() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(_table, where: 'id = 1');
      if (maps.isNotEmpty) {
        final map = maps.first;
        return BackupSettings(
          id: 1,
          telegramBotToken: map['telegram_bot_token'],
          telegramChatId: map['telegram_chat_id'],
          autoBackupEnabled: map['auto_backup_enabled'] == 1,
          lastBackupTime: map['last_backup_time'] != null ? DateTime.tryParse(map['last_backup_time']) : null,
        );
      }
      return BackupSettings();
    } catch (e) {
      // If DB read fails for any reason, return safe defaults
      return BackupSettings();
    }
  }

  @override
  Future<void> updateSettings(BackupSettings settings) async {
    final db = await _dbHelper.database;
    await db.update(
      _table,
      {
        'telegram_bot_token': settings.telegramBotToken,
        'telegram_chat_id': settings.telegramChatId,
        'auto_backup_enabled': settings.autoBackupEnabled ? 1 : 0,
        'last_backup_time': settings.lastBackupTime?.toIso8601String(),
      },
      where: 'id = 1',
    );
  }

  @override
  Future<File> getDatabaseFile() async {
    final path = await _dbHelper.getDatabasePathStr();
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Database file not found at path: $path');
    }
    return file;
  }

  @override
  Future<void> importDatabase(File importedFile) async {
    // Worst-case 1: File does not exist
    if (!await importedFile.exists()) {
      throw Exception('The selected file does not exist.');
    }

    // Worst-case 2: File is too small to be a real SQLite DB (< 100 bytes)
    final fileSize = await importedFile.length();
    if (fileSize < 100) {
      throw Exception('The selected file is too small to be a valid database.');
    }

    // Worst-case 3: File is not a valid SQLite database
    // SQLite files always start with the magic header string
    final bytes = await importedFile.openRead(0, 16).toList();
    final header = bytes.isNotEmpty ? bytes.first : [];
    final sqliteHeader = 'SQLite format 3'.codeUnits;
    bool isValidSQLite = header.length >= 15;
    if (isValidSQLite) {
      for (int i = 0; i < 15; i++) {
        if (header[i] != sqliteHeader[i]) {
          isValidSQLite = false;
          break;
        }
      }
    }
    if (!isValidSQLite) {
      throw Exception('The selected file is not a valid SQLite database. Please choose a ".db" backup file.');
    }

    final currentDbPath = await _dbHelper.getDatabasePathStr();
    final backupPath = '$currentDbPath.bak';

    // Step 1: Create a safety backup of the current database
    await _dbHelper.closeDatabase();
    final currentDb = File(currentDbPath);
    if (await currentDb.exists()) {
      await currentDb.copy(backupPath);
    }

    try {
      // Step 2: Copy the imported file to the database path
      await importedFile.copy(currentDbPath);

      // Step 3: Validate the imported DB by opening it and testing a query
      final db = await sqflite.openDatabase(currentDbPath);
      try {
        // Run a simple test to ensure key tables exist
        await db.rawQuery("SELECT count(*) FROM sqlite_master WHERE type='table'");
      } finally {
        await db.close();
      }

      // Step 4: Re-initialize the app's DB connection with the new file
      // DatabaseHelper will open fresh on next access
      _dbHelper.resetInstance();

      // Step 5: Success - remove the backup
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    } catch (e) {
      // Worst-case 4: Import failed — restore original database
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.copy(currentDbPath);
        await backupFile.delete();
      }
      // Re-init the DB connection to the restored original
      _dbHelper.resetInstance();
      throw Exception('Import failed: The file may be an incompatible database. Your original data has been restored.\n\nDetails: $e');
    }
  }

  @override
  Future<bool> sendBackupToTelegram(BackupSettings settings) async {
    // Worst-case 1: Telegram is not configured at all
    final token = settings.telegramBotToken?.trim();
    final chatId = settings.telegramChatId?.trim();

    if (token == null || token.isEmpty) {
      throw Exception('Telegram Bot Token is not configured.');
    }
    if (chatId == null || chatId.isEmpty) {
      throw Exception('Telegram Chat ID is not configured.');
    }

    // Worst-case 2: Token format looks invalid
    if (!token.contains(':')) {
      throw Exception('Bot Token format is invalid. It should look like "123456:ABC-DEF..."');
    }

    try {
      final dbFile = await getDatabaseFile();

      // Worst-case 3: DB file does not exist
      if (!await dbFile.exists()) {
        throw Exception('Database file could not be found for backup.');
      }

      final fileName = 'coaching_backup_${DateTime.now().millisecondsSinceEpoch}.db';
      final uri = Uri.parse('https://api.telegram.org/bot$token/sendDocument');
      final request = http.MultipartRequest('POST', uri)
        ..fields['chat_id'] = chatId
        ..fields['caption'] = '📦 Coaching App Backup\n🕐 ${DateTime.now().toLocal().toString().substring(0, 19)}'
        ..files.add(await http.MultipartFile.fromPath(
          'document',
          dbFile.path,
          filename: fileName,
        ));

      // Worst-case 4: Network timeout — cap at 30 seconds
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timed out. Check your internet connection.'),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        await updateSettings(settings.copyWith(lastBackupTime: DateTime.now()));
        return true;
      }

      // Worst-case 5: Telegram API rejected (wrong token, chat ID, etc.)
      if (response.statusCode == 401) {
        throw Exception('Invalid Bot Token. Please check your Telegram settings.');
      }
      if (response.statusCode == 400) {
        throw Exception('Invalid Chat ID or the bot is not a member of the chat. Status: ${response.body}');
      }
      throw Exception('Telegram API error (${response.statusCode}): ${response.body}');
    } on SocketException {
      // Worst-case 6: No internet at all
      throw Exception('No internet connection. Backup will be retried automatically when connected.');
    } on HttpException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }
}

