import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/backup_provider.dart';
import '../../../student/presentation/providers/student_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../fee/presentation/providers/fee_provider.dart';
import '../../../notes/presentation/providers/note_provider.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _botTokenCtrl;
  late TextEditingController _chatIdCtrl;
  bool _autoBackup = false;
  bool _tokenObscured = true;

  @override
  void initState() {
    super.initState();
    _botTokenCtrl = TextEditingController();
    _chatIdCtrl = TextEditingController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<BackupProvider>().settings;
      _botTokenCtrl.text = settings.telegramBotToken ?? '';
      _chatIdCtrl.text = settings.telegramChatId ?? '';
      setState(() {
        _autoBackup = settings.autoBackupEnabled;
      });
    });
  }

  @override
  void dispose() {
    _botTokenCtrl.dispose();
    _chatIdCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.error_outline, color: AppTheme.errorColor),
          SizedBox(width: 8),
          Text('Error'),
        ]),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(message))]),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _reloadAllProviders() {
    context.read<StudentProvider>().loadStudents();
    context.read<BatchProvider>().loadBatches();
    context.read<FeeProvider>().loadPendingFeeRecords();
    context.read<NoteProvider>().loadNotes();
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<BackupProvider>();
      final newSettings = provider.settings.copyWith(
        telegramBotToken: _botTokenCtrl.text.trim(),
        telegramChatId: _chatIdCtrl.text.trim(),
        autoBackupEnabled: _autoBackup,
      );
      
      final success = await provider.saveSettings(newSettings);
      if (mounted) {
        if (success) {
          _showSuccess('Settings saved successfully!');
        } else {
          _showError(provider.errorMessage ?? 'Failed to save settings.');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: Consumer<BackupProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final lastBackup = provider.settings.lastBackupTime;
          final isTelegramConfigured = (provider.settings.telegramBotToken?.trim().isNotEmpty ?? false) &&
              (provider.settings.telegramChatId?.trim().isNotEmpty ?? false);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === LOCAL BACKUP CARD ===
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.storage, size: 32, color: AppTheme.primaryColor),
                        title: Text('Local Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Export or import the SQLite database directly.'),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // EXPORT
                          TextButton.icon(
                            icon: const Icon(Icons.upload),
                            label: const Text('Export DB'),
                            onPressed: () async {
                              final success = await provider.exportDatabaseLocal();
                              if (!success && mounted && provider.errorMessage != null) {
                                _showError(provider.errorMessage!);
                              }
                            },
                          ),
                          // IMPORT
                          TextButton.icon(
                            icon: const Icon(Icons.download, color: AppTheme.errorColor),
                            label: const Text('Import DB', style: TextStyle(color: AppTheme.errorColor)),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => const ConfirmDialog(
                                  title: 'Import Database',
                                  content: 'This will OVERWRITE your current data with the imported file.\n\nYour current database is backed up automatically before replacement. If the file is invalid, it will be restored.',
                                ),
                              );
                              if (confirm == true && mounted) {
                                final result = await provider.importDatabaseLocal(
                                  onSuccess: _reloadAllProviders,
                                );
                                if (!mounted) return;
                                if (result == null) {
                                  // User cancelled
                                } else if (result == 'success') {
                                  _showSuccess('Database imported successfully! All data is now updated.');
                                } else {
                                  _showError(result); // Error message from provider
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Telegram Bot Integration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Automated daily backup sent to your Telegram chat, even when the app is closed.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                AppCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Token field
                        TextFormField(
                          controller: _botTokenCtrl,
                          obscureText: _tokenObscured,
                          decoration: InputDecoration(
                            labelText: 'Bot Token *',
                            hintText: '123456:ABC-DEFghIkl...',
                            suffixIcon: IconButton(
                              icon: Icon(_tokenObscured ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _tokenObscured = !_tokenObscured),
                            ),
                          ),
                          validator: (val) {
                            if (val != null && val.isNotEmpty && !val.contains(':')) {
                              return 'Invalid format. Token must contain ":"';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _chatIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Chat ID *',
                            hintText: '-100123456789',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto-Backup (Daily)'),
                          subtitle: const Text('Sends backup every 24h when connected'),
                          value: _autoBackup,
                          onChanged: (val) => setState(() => _autoBackup = val),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveSettings,
                            child: const Text('Save Telegram Settings'),
                          ),
                        ),
                        if (lastBackup != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            '✅ Last Backup: ${DateFormat('dd MMM yyyy, hh:mm a').format(lastBackup)}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Send Now button — disabled if not configured
                        Tooltip(
                          message: isTelegramConfigured ? '' : 'Save your Bot Token and Chat ID first',
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.send),
                              label: const Text('Send Backup Now'),
                              onPressed: isTelegramConfigured ? () async {
                                final error = await provider.sendToTelegram();
                                if (!mounted) return;
                                if (error == null) {
                                  _showSuccess('✅ Backup sent to Telegram successfully!');
                                } else {
                                  _showError(error);
                                }
                              } : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'Developed by',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Md Mim Shifat',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.email, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'mdshifat.official.05@gmail.com',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

