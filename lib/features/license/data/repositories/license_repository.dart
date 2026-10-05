import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/license_info.dart';

/// Result of a license activation attempt.
class ActivationResult {
  final bool success;
  final String message;
  final LicenseInfo? licenseInfo;

  const ActivationResult({
    required this.success,
    required this.message,
    this.licenseInfo,
  });
}

/// Repository that handles all license-related operations:
/// - Device ID extraction (stable, hardware-bound)
/// - Local secure storage (for offline mode)
/// - Firebase Firestore verification & activation (with transactions)
/// - Periodic online re-validation
///
/// All licenses are LIFETIME — there is no expiry date.
class LicenseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const _androidId = AndroidId();

  static const String _collectionName = 'licenses';

  // Local storage keys
  static const String _keyLicenseKey = 'license_key';
  static const String _keyDeviceId = 'license_device_id';
  static const String _keyUserName = 'license_user_name';
  static const String _keyPhoneNumber = 'license_phone_number';
  static const String _keyActivatedAt = 'license_activated_at';
  static const String _keyIsActive = 'license_is_active';
  static const String _keyLastOnlineCheck = 'license_last_online_check';

  /// Get a stable, unique Device ID for this phone.
  /// 
  /// On Android: Uses Settings.Secure.ANDROID_ID which is:
  /// - Unique per device + app signing key + user
  /// - Persists across app uninstall/reinstall (same signing key)
  /// - Only resets on factory reset
  ///
  /// On iOS: Uses identifierForVendor.
  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final id = await _androidId.getId();
        return id ?? 'unknown_android';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios';
      }
    } catch (e) {
      // If device info retrieval fails, return a fallback.
      // The license check will likely fail on device mismatch, but won't crash.
    }
    return 'unknown_device';
  }

  /// Check if there is a valid local activation stored on this device.
  /// This enables offline usage after initial activation.
  Future<LicenseInfo?> getLocalActivation() async {
    try {
      final licenseKey = await _secureStorage.read(key: _keyLicenseKey);
      if (licenseKey == null || licenseKey.isEmpty) return null;

      final deviceId = await _secureStorage.read(key: _keyDeviceId) ?? '';
      final userName = await _secureStorage.read(key: _keyUserName) ?? '';
      final phoneNumber = await _secureStorage.read(key: _keyPhoneNumber) ?? '';
      final activatedAtStr = await _secureStorage.read(key: _keyActivatedAt) ?? '';
      final isActiveStr = await _secureStorage.read(key: _keyIsActive);

      // If isActive was explicitly set to false (admin revoked during last online check)
      if (isActiveStr == 'false') {
        await clearLocalActivation();
        return null;
      }

      // Verify device ID matches current phone
      final currentDeviceId = await getDeviceId();
      if (deviceId.isNotEmpty && deviceId != currentDeviceId) {
        // Device mismatch — someone copied the app data to another phone
        // (though flutter_secure_storage should already prevent this on Android)
        await clearLocalActivation();
        return null;
      }

      return LicenseInfo(
        licenseKey: licenseKey,
        isActive: true,
        deviceId: deviceId,
        userName: userName,
        phoneNumber: phoneNumber,
        activatedAt: activatedAtStr.isNotEmpty
            ? DateTime.tryParse(activatedAtStr)
            : null,
      );
    } catch (e) {
      // Secure storage can throw on corrupted data or keystore issues.
      // Don't crash — just treat as not activated.
      return null;
    }
  }

  /// Save activation data to local secure storage for offline usage.
  Future<void> _saveLocalActivation(LicenseInfo info) async {
    try {
      await _secureStorage.write(key: _keyLicenseKey, value: info.licenseKey);
      await _secureStorage.write(key: _keyDeviceId, value: info.deviceId);
      await _secureStorage.write(key: _keyUserName, value: info.userName);
      await _secureStorage.write(key: _keyPhoneNumber, value: info.phoneNumber);
      await _secureStorage.write(key: _keyIsActive, value: info.isActive.toString());
      await _secureStorage.write(
        key: _keyActivatedAt,
        value: info.activatedAt?.toIso8601String() ?? '',
      );
      await _secureStorage.write(
        key: _keyLastOnlineCheck,
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      // If saving fails, the app still works for this session
      // but won't remember activation next launch.
    }
  }

  /// Clear all local activation data (used when license is revoked or device mismatch).
  Future<void> clearLocalActivation() async {
    try {
      await _secureStorage.delete(key: _keyLicenseKey);
      await _secureStorage.delete(key: _keyDeviceId);
      await _secureStorage.delete(key: _keyUserName);
      await _secureStorage.delete(key: _keyPhoneNumber);
      await _secureStorage.delete(key: _keyActivatedAt);
      await _secureStorage.delete(key: _keyIsActive);
      await _secureStorage.delete(key: _keyLastOnlineCheck);
    } catch (e) {
      // Best-effort cleanup — don't crash if storage is already corrupted.
    }
  }

  /// Activate a license key with the given user info.
  /// Uses a Firestore TRANSACTION to prevent race conditions where
  /// two devices try to activate the same key at the same moment.
  /// Requires internet connection.
  Future<ActivationResult> activateLicense({
    required String licenseKey,
    required String userName,
    required String phoneNumber,
  }) async {
    try {
      final trimmedKey = licenseKey.trim().toUpperCase();
      final currentDeviceId = await getDeviceId();

      final docRef = _firestore.collection(_collectionName).doc(trimmedKey);

      // Use a TRANSACTION to ensure atomic read-check-write.
      // If another device writes between our read and write, the transaction
      // automatically retries, preventing duplicate activations.
      final result = await _firestore.runTransaction<ActivationResult>(
        (transaction) async {
          // 1. Read the document inside the transaction
          final docSnapshot = await transaction.get(docRef);

          if (!docSnapshot.exists) {
            return const ActivationResult(
              success: false,
              message: 'Invalid license key. Please check and try again.',
            );
          }

          final data = docSnapshot.data()!;

          // 2. Check if the key is active
          final isActive = data['isActive'] ?? false;
          if (!isActive) {
            return const ActivationResult(
              success: false,
              message: 'This license key has been deactivated. Please contact the developer.',
            );
          }

          // 3. Check if already used on another device
          final existingDeviceId = data['deviceId'] ?? '';
          if (existingDeviceId.isNotEmpty && existingDeviceId != currentDeviceId) {
            return const ActivationResult(
              success: false,
              message: 'This license key is already in use on another device.',
            );
          }

          // 4. All checks passed — activate inside the transaction!
          transaction.update(docRef, {
            'deviceId': currentDeviceId,
            'userName': userName.trim(),
            'phoneNumber': phoneNumber.trim(),
            'activatedAt': FieldValue.serverTimestamp(),
          });

          final now = DateTime.now();
          return ActivationResult(
            success: true,
            message: 'License activated successfully!',
            licenseInfo: LicenseInfo(
              licenseKey: trimmedKey,
              isActive: true,
              deviceId: currentDeviceId,
              userName: userName.trim(),
              phoneNumber: phoneNumber.trim(),
              activatedAt: now,
            ),
          );
        },
      );

      // If activation succeeded, save locally for offline usage
      if (result.success && result.licenseInfo != null) {
        await _saveLocalActivation(result.licenseInfo!);
      }

      return result;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'PERMISSION_DENIED') {
        return const ActivationResult(
          success: false,
          message: 'Permission denied. Please contact the developer.',
        );
      }
      return ActivationResult(
        success: false,
        message: 'Server error. Please try again later. (${e.code})',
      );
    } on SocketException catch (_) {
      return const ActivationResult(
        success: false,
        message: 'No internet connection. Please check your network and try again.',
      );
    } catch (e) {
      return const ActivationResult(
        success: false,
        message: 'Network error. Please check your internet connection and try again.',
      );
    }
  }

  /// Silently re-validate the license with Firebase when internet is available.
  /// Call this periodically (e.g., on app start when online).
  /// Returns true if license is still valid, false if revoked.
  /// Returns true on network errors (don't punish user for bad connectivity).
  Future<bool> revalidateOnline() async {
    try {
      final licenseKey = await _secureStorage.read(key: _keyLicenseKey);
      if (licenseKey == null || licenseKey.isEmpty) return false;

      final currentDeviceId = await getDeviceId();

      final docRef = _firestore.collection(_collectionName).doc(licenseKey);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        await clearLocalActivation();
        return false;
      }

      final data = docSnapshot.data()!;

      // Check if admin deactivated it
      if (data['isActive'] == false) {
        await clearLocalActivation();
        return false;
      }

      // Check device ID still matches
      final storedDeviceId = data['deviceId'] ?? '';
      if (storedDeviceId.isNotEmpty && storedDeviceId != currentDeviceId) {
        await clearLocalActivation();
        return false;
      }

      // All good — update last online check timestamp
      try {
        await _secureStorage.write(
          key: _keyLastOnlineCheck,
          value: DateTime.now().toIso8601String(),
        );
      } catch (_) {}

      return true;
    } on FirebaseException catch (e) {
      // Permission denied = likely admin changed rules or revoked access
      if (e.code == 'permission-denied' || e.code == 'PERMISSION_DENIED') {
        try {
          await clearLocalActivation();
        } catch (_) {}
        return false;
      }
      // Other Firebase errors (unavailable, deadline-exceeded, etc.) = network issue
      // Don't revoke — keep offline mode working
      return true;
    } on SocketException catch (_) {
      // No internet — don't revoke, keep offline mode working
      return true;
    } catch (e) {
      // Unknown error — don't revoke, let the user keep working offline
      return true;
    }
  }
}
