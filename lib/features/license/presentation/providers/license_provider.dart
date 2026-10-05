import 'package:flutter/foundation.dart';
import '../../data/models/license_info.dart';
import '../../data/repositories/license_repository.dart';

/// Possible states of the license check flow.
enum LicenseStatus {
  /// Initial state — checking local storage
  checking,
  /// License is valid (either local or online verified)
  activated,
  /// No valid license found — show activation screen
  notActivated,
  /// Currently attempting to activate a license key
  activating,
  /// Activation failed (with error message)
  error,
}

/// Provider for license state management.
/// Handles checking, activating, and revoking lifetime licenses.
class LicenseProvider extends ChangeNotifier {
  final LicenseRepository _repository;

  LicenseStatus _status = LicenseStatus.checking;
  LicenseInfo? _licenseInfo;
  String _errorMessage = '';
  bool _isDisposed = false;

  LicenseProvider(this._repository);

  LicenseStatus get status => _status;
  LicenseInfo? get licenseInfo => _licenseInfo;
  String get errorMessage => _errorMessage;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Safely notify listeners only if this provider hasn't been disposed.
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Check if there is a valid local activation.
  /// Called during splash screen to determine which screen to show.
  Future<void> checkActivation() async {
    _status = LicenseStatus.checking;
    _safeNotifyListeners();

    try {
      final localLicense = await _repository.getLocalActivation();

      if (localLicense != null) {
        _licenseInfo = localLicense;
        _status = LicenseStatus.activated;

        // Silently try to re-validate online (non-blocking)
        _revalidateInBackground();
      } else {
        _status = LicenseStatus.notActivated;
      }
    } catch (e) {
      _status = LicenseStatus.notActivated;
    }

    _safeNotifyListeners();
  }

  /// Attempt to activate a license key with user info.
  Future<bool> activateLicense({
    required String licenseKey,
    required String userName,
    required String phoneNumber,
  }) async {
    _status = LicenseStatus.activating;
    _errorMessage = '';
    _safeNotifyListeners();

    try {
      final result = await _repository.activateLicense(
        licenseKey: licenseKey,
        userName: userName,
        phoneNumber: phoneNumber,
      );

      if (_isDisposed) return result.success;

      if (result.success) {
        _licenseInfo = result.licenseInfo;
        _status = LicenseStatus.activated;
        _errorMessage = '';
      } else {
        _status = LicenseStatus.error;
        _errorMessage = result.message;
      }

      _safeNotifyListeners();
      return result.success;
    } catch (e) {
      if (_isDisposed) return false;
      _status = LicenseStatus.error;
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _safeNotifyListeners();
      return false;
    }
  }

  /// Silently re-validate online without blocking the UI.
  /// If the license was revoked by admin, updates status to trigger redirect.
  void _revalidateInBackground() async {
    try {
      final isValid = await _repository.revalidateOnline();
      if (!isValid && !_isDisposed) {
        _status = LicenseStatus.notActivated;
        _licenseInfo = null;
        _errorMessage = 'Your license has been revoked. Please contact the developer.';
        _safeNotifyListeners();
      }
    } catch (_) {
      // Network error — don't disturb the user, keep offline mode working
    }
  }

  /// Clear activation and return to activation screen.
  Future<void> deactivate() async {
    try {
      await _repository.clearLocalActivation();
    } catch (_) {}
    _licenseInfo = null;
    _status = LicenseStatus.notActivated;
    _errorMessage = '';
    _safeNotifyListeners();
  }
}
