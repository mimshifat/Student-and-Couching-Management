/// Data model representing a lifetime software license with device binding.
class LicenseInfo {
  final String licenseKey;
  final bool isActive;
  final String deviceId;
  final String userName;
  final String phoneNumber;
  final DateTime? activatedAt;
  final DateTime? createdAt;
  final String notes;

  const LicenseInfo({
    required this.licenseKey,
    required this.isActive,
    required this.deviceId,
    required this.userName,
    required this.phoneNumber,
    this.activatedAt,
    this.createdAt,
    this.notes = '',
  });

  /// Whether this license has been activated on any device.
  bool get isActivated => deviceId.isNotEmpty;

  /// Create from Firestore document data with safe parsing.
  factory LicenseInfo.fromFirestore(String key, Map<String, dynamic> data) {
    return LicenseInfo(
      licenseKey: key,
      isActive: data['isActive'] ?? false,
      deviceId: data['deviceId'] ?? '',
      userName: data['userName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      activatedAt: _safeParseDateTime(data['activatedAt']),
      createdAt: _safeParseDateTime(data['createdAt']),
      notes: data['notes'] ?? '',
    );
  }

  /// Safely parse a Firestore Timestamp, DateTime, or ISO string to DateTime.
  /// Returns null if parsing fails instead of crashing.
  static DateTime? _safeParseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      // Firestore Timestamp has a toDate() method
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {}
    // Fallback: try parsing as ISO 8601 string
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  /// Convert to a map for local secure storage.
  Map<String, String> toLocalStorage() {
    return {
      'licenseKey': licenseKey,
      'isActive': isActive.toString(),
      'deviceId': deviceId,
      'userName': userName,
      'phoneNumber': phoneNumber,
      'activatedAt': activatedAt?.toIso8601String() ?? '',
    };
  }

  /// Create from local secure storage data.
  factory LicenseInfo.fromLocalStorage(Map<String, String> data) {
    return LicenseInfo(
      licenseKey: data['licenseKey'] ?? '',
      // Default to true if missing (backward compatibility with old storage)
      isActive: data['isActive'] != 'false',
      deviceId: data['deviceId'] ?? '',
      userName: data['userName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      activatedAt: data['activatedAt']?.isNotEmpty == true
          ? DateTime.tryParse(data['activatedAt']!)
          : null,
    );
  }
}
