class BackupSettings {
  final int id;
  final String? telegramBotToken;
  final String? telegramChatId;
  final bool autoBackupEnabled;
  final DateTime? lastBackupTime;

  BackupSettings({
    this.id = 1,
    this.telegramBotToken,
    this.telegramChatId,
    this.autoBackupEnabled = false,
    this.lastBackupTime,
  });

  BackupSettings copyWith({
    String? telegramBotToken,
    String? telegramChatId,
    bool? autoBackupEnabled,
    DateTime? lastBackupTime,
  }) {
    return BackupSettings(
      id: id,
      telegramBotToken: telegramBotToken ?? this.telegramBotToken,
      telegramChatId: telegramChatId ?? this.telegramChatId,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      lastBackupTime: lastBackupTime ?? this.lastBackupTime,
    );
  }
}
