import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Represents the current state of the 14-day free trial.
class TrialStatus {
  final bool isActive;
  final bool isExpired;
  final bool hasStarted;
  final DateTime? startDate;
  final int daysRemaining;

  static const int totalDays = 14;

  const TrialStatus({
    required this.isActive,
    required this.isExpired,
    required this.hasStarted,
    this.startDate,
    required this.daysRemaining,
  });
}

/// Manages the 14-day free trial period.
///
/// ## Strategy: Local-first + Opportunistic Firebase sync
///
/// - [flutter_secure_storage] is the **primary source of truth** — works fully offline.
/// - Firebase is synced **fire-and-forget** when internet is available.
/// - **Anti-cheat:** If Firebase records an *earlier* trial start date than local
///   (meaning the user cleared app data to reset their trial), local storage is
///   silently corrected on the next app launch.
class TrialRepository {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _androidId = AndroidId();

  // Local storage keys
  static const String _keyTrialStartDate = 'trial_start_date';
  static const String _keyTrialDeviceId = 'trial_device_id';

  // Firestore collection
  static const String _firestoreCollection = 'trial_devices';

  static const int _trialDays = TrialStatus.totalDays;

  Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        return await _androidId.getId() ?? 'unknown_android';
      }
    } catch (_) {}
    return 'unknown_device';
  }

  /// Initialize trial and return its current status.
  ///
  /// Safe to call on every app launch — fully idempotent.
  /// - If this is the first ever launch: starts the trial clock.
  /// - Otherwise: calculates remaining days from stored start date.
  /// - Always kicks off a background Firebase sync (non-blocking).
  Future<TrialStatus> initAndGetTrialStatus() async {
    try {
      final storedDateStr = await _secureStorage.read(key: _keyTrialStartDate);

      if (storedDateStr == null || storedDateStr.isEmpty) {
        // ── First ever launch: start the trial ──
        final now = DateTime.now();
        final deviceId = await _getDeviceId();
        await _writeTrialToLocalStorage(startDate: now, deviceId: deviceId);
        _syncWithFirebase(deviceId: deviceId, localStartDate: now); // fire-and-forget
        return _buildStatus(startDate: now);
      }

      // ── Trial already started: calculate remaining days ──
      final localStart = DateTime.tryParse(storedDateStr) ?? DateTime.now();
      final deviceId = await _getDeviceId();

      // Opportunistic Firebase sync (non-blocking anti-cheat check)
      _syncWithFirebase(deviceId: deviceId, localStartDate: localStart);

      return _buildStatus(startDate: localStart);
    } catch (_) {
      // If secure storage fails for any reason, grant trial access.
      // Never block the user because of our own bugs.
      return const TrialStatus(
        isActive: true,
        isExpired: false,
        hasStarted: false,
        daysRemaining: _trialDays,
      );
    }
  }

  Future<void> _writeTrialToLocalStorage({
    required DateTime startDate,
    required String deviceId,
  }) async {
    await _secureStorage.write(
      key: _keyTrialStartDate,
      value: startDate.toIso8601String(),
    );
    await _secureStorage.write(key: _keyTrialDeviceId, value: deviceId);
  }

  TrialStatus _buildStatus({required DateTime startDate}) {
    final daysPassed = DateTime.now().difference(startDate).inDays;
    final daysRemaining = (_trialDays - daysPassed).clamp(0, _trialDays);
    final isExpired = daysPassed >= _trialDays;

    return TrialStatus(
      isActive: !isExpired,
      isExpired: isExpired,
      hasStarted: true,
      startDate: startDate,
      daysRemaining: daysRemaining,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Firebase sync (fire-and-forget, fully non-blocking)
  // ─────────────────────────────────────────────────────────────────────────

  /// Triggers a background Firebase sync. Any error (network, timeout, etc.)
  /// is silently swallowed — offline usage is never affected.
  void _syncWithFirebase({
    required String deviceId,
    required DateTime localStartDate,
  }) {
    _doFirebaseSync(deviceId: deviceId, localStartDate: localStartDate)
        .timeout(const Duration(seconds: 8))
        .catchError((_) {}); // Silently ignore all errors
  }

  Future<void> _doFirebaseSync({
    required String deviceId,
    required DateTime localStartDate,
  }) async {
    final docRef = _firestore.collection(_firestoreCollection).doc(deviceId);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);

      if (!doc.exists) {
        // First time we see this device on Firebase — record the trial start.
        transaction.set(docRef, {
          'deviceId': deviceId,
          'trialStartDate': localStartDate.toIso8601String(),
          'firstSeenAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Device known. Check for earlier date (anti-cheat).
        final firebaseDateStr = doc.data()?['trialStartDate'] as String?;
        final firebaseStart =
            firebaseDateStr != null ? DateTime.tryParse(firebaseDateStr) : null;

        if (firebaseStart != null && firebaseStart.isBefore(localStartDate)) {
          // Firebase has an earlier trial start date.
          // This means the user cleared app data to reset the 14-day clock.
          // Silently update local storage. The corrected date takes effect
          // on the NEXT app launch (we don't interrupt the current session).
          try {
            await _secureStorage.write(
              key: _keyTrialStartDate,
              value: firebaseStart.toIso8601String(),
            );
          } catch (_) {}
        }

        transaction.update(docRef, {
          'lastSeenAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
