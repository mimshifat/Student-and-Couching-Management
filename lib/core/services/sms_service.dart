import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';

class SmsSendResult {
  final bool success;
  final String mode;
  final String? message;

  const SmsSendResult({
    required this.success,
    required this.mode,
    this.message,
  });
}

class SimDeviceInfo {
  final int maxSlots;
  final List<int> activeSlots;
  final Map<String, String> carriers;

  const SimDeviceInfo({
    this.maxSlots = 1,
    this.activeSlots = const [0],
    this.carriers = const {},
  });

  bool get isSingleSlotDevice => maxSlots <= 1;
  bool isSlotActive(int slotIndex) => activeSlots.contains(slotIndex);
  String? getCarrierName(int slotIndex) {
    final raw = carriers[slotIndex.toString()];
    if (raw == null || raw.trim().isEmpty) return null;
    return SmsService.formatCarrierName(raw);
  }
}

class SmsService {
  static const MethodChannel _channel = MethodChannel('com.coaching.student_management/sms');
  static final DatabaseHelper _dbHelper = DatabaseHelper();

  // Mode constants
  static const String modeDefaultApp = 'default_app';
  static const String modeNoSms = 'no_sms';
  static const String modeAutoSim1 = 'auto_sim_1';
  static const String modeAutoSim2 = 'auto_sim_2';

  /// Normalizes carrier names for Bangladesh & roaming operators
  static String formatCarrierName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final lower = raw.trim().toLowerCase();

    // Check specific brands first
    if (lower.contains('skitto')) return 'Skitto';
    if (lower.contains('airtel') || lower.contains('robi-airtel') || lower.contains('airtel-robi')) return 'Airtel';
    if (lower.contains('robi')) return 'Robi';
    if (lower.contains('grameen') || lower == 'gp' || lower.startsWith('gp ') || lower.endsWith(' gp')) {
      return 'Grameenphone';
    }
    if (lower.contains('banglalink') || lower == 'bl' || lower.startsWith('bl ') || lower.endsWith(' bl')) {
      return 'Banglalink';
    }
    if (lower.contains('teletalk')) return 'Teletalk';
    if (lower.contains('citycell')) return 'Citycell';
    if (lower == '47001') return 'Grameenphone';
    if (lower == '47002') return 'Robi';
    if (lower == '47003') return 'Banglalink';
    if (lower == '47004') return 'Teletalk';
    if (lower == '47007') return 'Airtel';

    // Strip trailing generation markers (e.g. " 4G", " 5G", " LTE")
    return raw.replaceAll(RegExp(r'\s+(4G|5G|3G|LTE|GSM)$', caseSensitive: false), '').trim();
  }

  /// Extracts clean batch name without schedule days and time slot
  static String cleanBatchName(String? snapshot) {
    if (snapshot == null || snapshot.trim().isEmpty) return '';
    var name = snapshot.trim();
    // Strip trailing schedule like "(Everyday | 7:00 AM – 8:00 AM)"
    name = name.replaceAll(RegExp(r'\s*\([^)]*\|[^)]*\)\s*$'), '').trim();
    if (name.contains('(') && !snapshot.startsWith('(')) {
      final beforeParen = name.split('(').first.trim();
      if (beforeParen.isNotEmpty) {
        name = beforeParen;
      }
    }
    return name;
  }

  /// Formats batch part for SMS text (e.g., " (Batch: Class 8: Math & Science)")
  static String formatBatchPart(String? snapshot) {
    final clean = cleanBatchName(snapshot);
    return clean.isNotEmpty ? ' (Batch: $clean)' : '';
  }

  /// Fetch hardware & active SIM status from Android
  static Future<SimDeviceInfo> getSimDeviceInfo() async {
    if (!Platform.isAndroid) {
      return const SimDeviceInfo();
    }
    try {
      final res = await _channel.invokeMethod<Map>('getSimInfo').timeout(const Duration(seconds: 4));
      if (res != null) {
        final maxSlots = (res['maxSlots'] as num?)?.toInt() ?? 1;
        final rawActive = (res['activeSlots'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0];
        final rawCarriers = (res['carriers'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {};
        return SimDeviceInfo(
          maxSlots: maxSlots,
          activeSlots: rawActive,
          carriers: rawCarriers,
        );
      }
    } catch (_) {}
    return const SimDeviceInfo();
  }

  /// Get currently configured SMS mode (Defaults to 'default_app')
  static Future<String> getSmsMode() async {
    try {
      final db = await _dbHelper.database;
      final res = await db.query('sms_settings', where: 'id = 1');
      if (res.isNotEmpty && res.first['sms_mode'] != null) {
        return res.first['sms_mode'] as String;
      }
    } catch (_) {}
    return modeDefaultApp;
  }

  /// Save selected SMS mode
  static Future<void> setSmsMode(String mode) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.update(
        'sms_settings',
        {'sms_mode': mode},
        where: 'id = 1',
      );
      if (count == 0) {
        await db.insert('sms_settings', {'id': 1, 'sms_mode': mode, 'sim_slot': 1});
      }
    } catch (_) {}
  }

  /// Converts Bengali numerals (০-৯) to standard English digits (0-9)
  static String convertBengaliDigits(String input) {
    const bengali = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    var result = input;
    for (var i = 0; i < bengali.length; i++) {
      result = result.replaceAll(bengali[i], english[i]);
    }
    return result;
  }

  /// Send SMS according to current configuration or overrideMode
  static Future<SmsSendResult> sendSms({
    required String phone,
    required String message,
    String? overrideMode,
  }) async {
    final mode = overrideMode ?? await getSmsMode();

    if (mode == modeNoSms) {
      return const SmsSendResult(
        success: true,
        mode: modeNoSms,
        message: 'SMS sending is turned off.',
      );
    }

    final normalizedPhone = convertBengaliDigits(phone);
    final cleanPhone = normalizedPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final digitsOnly = cleanPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 5) {
      return SmsSendResult(
        success: false,
        mode: mode,
        message: 'Invalid phone number.',
      );
    }

    if (mode == modeDefaultApp) {
      try {
        final uri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) {
            return const SmsSendResult(
              success: true,
              mode: modeDefaultApp,
              message: 'Opened messaging app.',
            );
          }
        }
        return const SmsSendResult(
          success: false,
          mode: modeDefaultApp,
          message: 'No messaging app found on your phone.',
        );
      } catch (e) {
        return SmsSendResult(
          success: false,
          mode: modeDefaultApp,
          message: 'Could not open messaging app: ${e.toString()}',
        );
      }
    }

    if (mode == modeAutoSim1 || mode == modeAutoSim2) {
      if (!Platform.isAndroid) {
        return SmsSendResult(
          success: false,
          mode: mode,
          message: 'Direct background SMS is only supported on Android devices.',
        );
      }

      // 0 for SIM 1, 1 for SIM 2
      final simSlot = mode == modeAutoSim1 ? 0 : 1;

      // Request SMS Permission
      PermissionStatus smsStatus;
      try {
        smsStatus = await Permission.sms.request().timeout(const Duration(seconds: 15));
      } catch (e) {
        smsStatus = await Permission.sms.status;
      }

      if (!smsStatus.isGranted) {
        if (smsStatus.isPermanentlyDenied) {
          return SmsSendResult(
            success: false,
            mode: mode,
            message: 'SMS permission is disabled. Please enable it from Android App Settings.',
          );
        }
        return SmsSendResult(
          success: false,
          mode: mode,
          message: 'SMS permission was not granted.',
        );
      }

      // Request Phone State Permission (for SIM selection) safely
      try {
        await Permission.phone.request().timeout(const Duration(seconds: 10));
      } catch (_) {}

      try {
        final result = await _channel.invokeMethod<bool>('sendSms', {
          'phone': cleanPhone,
          'message': message,
          'simSlot': simSlot,
        }).timeout(const Duration(seconds: 8));

        if (result == true) {
          final simLabel = mode == modeAutoSim1 ? 'SIM 1' : 'SIM 2';
          return SmsSendResult(
            success: true,
            mode: mode,
            message: 'SMS sent successfully via $simLabel.',
          );
        } else {
          return SmsSendResult(
            success: false,
            mode: mode,
            message: 'Failed to send SMS via SIM.',
          );
        }
      } on TimeoutException {
        return SmsSendResult(
          success: false,
          mode: mode,
          message: 'SMS request timed out. Please check your SIM network signal.',
        );
      } on PlatformException catch (e) {
        return SmsSendResult(
          success: false,
          mode: mode,
          message: e.message ?? 'Native SMS error',
        );
      } catch (e) {
        return SmsSendResult(
          success: false,
          mode: mode,
          message: e.toString(),
        );
      }
    }

    return const SmsSendResult(
      success: false,
      mode: 'unknown',
      message: 'Unknown SMS mode.',
    );
  }
}
