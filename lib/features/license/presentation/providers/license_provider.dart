import 'package:flutter/foundation.dart';
import '../../data/models/license_info.dart';
import '../../data/repositories/license_repository.dart';
import '../../data/repositories/trial_repository.dart';

/// Possible states of the license / trial check flow.
enum LicenseStatus {
  /// Initial state — checking local storage.
  checking,

  /// License is valid (locally verified, with background online re-validation).
  activated,

  /// App is running under the 14-day free trial.
  trialActive,

  /// Free trial has expired — user must activate a license key.
  trialExpired,

  /// No valid license and trial check not applicable (legacy / fallback).
  notActivated,

  /// Currently attempting to activate a license key.
  activating,

  /// Activation failed (see [LicenseProvider.errorMessage]).
  error,
}

/// Provider for license + trial state management.
class LicenseProvider extends ChangeNotifier {
  final LicenseRepository _repository;
  final TrialRepository _trialRepository;

  LicenseStatus _status = LicenseStatus.checking;
  LicenseInfo? _licenseInfo;
  String _errorMessage = '';
  bool _isDisposed = false;
  TrialStatus? _trialStatus;

  LicenseProvider(this._repository, this._trialRepository);

  LicenseStatus get status => _status;
  LicenseInfo? get licenseInfo => _licenseInfo;
  String get errorMessage => _errorMessage;

  /// Days remaining in free trial (0 if not on trial or expired).
  int get trialDaysRemaining => _trialStatus?.daysRemaining ?? 0;

  /// Whether the app is currently running under the free trial.
  bool get isOnTrial => _status == LicenseStatus.trialActive;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  /// Check license + trial status. Called from SplashScreen.
  Future<void> checkActivation() async {
    _status = LicenseStatus.checking;
    _safeNotifyListeners();

    try {
      final localLicense = await _repository.getLocalActivation();

      if (localLicense != null) {
        // ── Valid license found ──
        _licenseInfo = localLicense;
        _status = LicenseStatus.activated;
        _revalidateInBackground();
      } else {
        // ── No license → check trial ──
        final trialStatus = await _trialRepository.initAndGetTrialStatus();
        _trialStatus = trialStatus;

        if (trialStatus.isActive) {
          _status = LicenseStatus.trialActive;
        } else {
          _status = LicenseStatus.trialExpired;
        }
      }
    } catch (e) {
      _status = LicenseStatus.notActivated;
    }

    _safeNotifyListeners();
  }

  /// Attempt to activate a license key. Can be called during trial or after expiry.
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
        // Restore previous state on failure (trial or expired)
        if (_trialStatus != null) {
          _status = _trialStatus!.isExpired
              ? LicenseStatus.trialExpired
              : LicenseStatus.trialActive;
        } else {
          _status = LicenseStatus.error;
        }
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
  void _revalidateInBackground() async {
    try {
      final isValid = await _repository.revalidateOnline();
      if (!isValid && !_isDisposed) {
        _status = LicenseStatus.notActivated;
        _licenseInfo = null;
        _errorMessage =
            'Your license has been revoked. Please contact the developer.';
        _safeNotifyListeners();
      }
    } catch (_) {
      // Network error — keep offline mode working
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
