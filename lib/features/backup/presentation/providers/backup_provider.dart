import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/backup_settings.dart';
import '../../domain/repositories/backup_repository.dart';

class BackupProvider with ChangeNotifier {
  final BackupRepository _repository;

  BackupSettings _settings = BackupSettings();
  BackupSettings get settings => _settings;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  BackupProvider(this._repository) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _settings = await _repository.getSettings();
    } catch (e) {
      _errorMessage = 'Failed to load settings: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveSettings(BackupSettings newSettings) async {
    try {
      await _repository.updateSettings(newSettings);
      _settings = newSettings;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> exportDatabaseLocal() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final dbFile = await _repository.getDatabaseFile();
      if (await dbFile.exists()) {
        // ignore: deprecated_member_use
        final result = await Share.shareXFiles([XFile(dbFile.path)], text: 'Coaching App Database Backup');
        if (result.status == ShareResultStatus.dismissed) {
          _errorMessage = 'Backup cancelled.';
          return false;
        }
        return result.status == ShareResultStatus.success || result.status == ShareResultStatus.unavailable;
      }
      _errorMessage = 'Database file not found.';
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// [onSuccess] is called after a successful import so callers can
  /// trigger an immediate reload of all providers in the app.
  Future<String?> importDatabaseLocal({VoidCallback? onSuccess}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        _isLoading = false;
        notifyListeners();
        return null; // User cancelled
      }

      File file = File(result.files.single.path!);
      await _repository.importDatabase(file);

      // Import succeeded — trigger instant refresh of all providers
      onSuccess?.call();
      return 'success';
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return _errorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> sendToTelegram() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await _repository.sendBackupToTelegram(_settings);
      await loadSettings(); // Refresh last backup time
      return null; // null = success
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return _errorMessage; // return error message string
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

