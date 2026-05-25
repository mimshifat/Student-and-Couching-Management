import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    });
  }

  @override
  void dispose() {
    _botTokenCtrl.dispose();
    _chatIdCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  void _reloadAllProviders() {
    context.read<StudentProvider>().loadStudents();
    context.read<BatchProvider>().loadBatches();
    context.read<FeeProvider>().loadPendingFeeRecords();
    context.read<NoteProvider>().loadNotes();
  }

  void _showTelegramSetupDialog(BackupProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Telegram Setup', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Once configured successfully, auto backup is enabled automatically.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _botTokenCtrl,
                      obscureText: _tokenObscured,
                      decoration: InputDecoration(
                        labelText: 'Bot Token *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(_tokenObscured ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setModalState(() => _tokenObscured = !_tokenObscured),
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
                      decoration: InputDecoration(
                        labelText: 'Chat ID *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4338CA),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final newSettings = provider.settings.copyWith(
                              telegramBotToken: _botTokenCtrl.text.trim(),
                              telegramChatId: _chatIdCtrl.text.trim(),
                              autoBackupEnabled: true, // Enable auto-backup as requested
                            );
                            final success = await provider.saveSettings(newSettings);
                            if (mounted) {
                              if (success) {
                                Navigator.pop(context);
                                _showSuccess('Telegram configured and auto backup enabled!');
                                // Auto send backup after configuration
                                provider.sendToTelegram();
                              } else {
                                _showError(provider.errorMessage ?? 'Failed to save settings.');
                              }
                            }
                          }
                        },
                        child: const Text('Save & Enable Auto Backup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFF4338CA)),
                        ),
                        onPressed: () async {
                           final error = await provider.sendToTelegram();
                           if (mounted) {
                             if (error == null) {
                               _showSuccess('Backup sent to Telegram successfully!');
                             } else {
                               _showError(error);
                             }
                           }
                        },
                        child: const Text('Send Backup Now', style: TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 24, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF4338CA),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Consumer<BackupProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Backup & Restore'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildListTile(
                        icon: Icons.cloud_upload_outlined,
                        iconColor: const Color(0xFF5E60CE),
                        iconBgColor: const Color(0xFFEEF0FE),
                        title: 'Backup Database',
                        subtitle: 'Create a backup of your database',
                        onTap: () async {
                          final success = await provider.exportDatabaseLocal();
                          if (!success && provider.errorMessage != null) {
                            _showError(provider.errorMessage!);
                          } else if (success) {
                            _showSuccess('Backup exported successfully');
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 64),
                      _buildListTile(
                        icon: Icons.cloud_download_outlined,
                        iconColor: const Color(0xFF2B9348),
                        iconBgColor: const Color(0xFFE8F8EE),
                        title: 'Restore Database',
                        subtitle: 'Restore your database from backup file',
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Restore Database'),
                              content: const Text('This will OVERWRITE your current data with the imported file. Are you sure?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final result = await provider.importDatabaseLocal(onSuccess: _reloadAllProviders);
                            if (result == 'success') {
                              _showSuccess('Database restored successfully!');
                            } else if (result != null) {
                              _showError(result);
                            }
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 64),
                      _buildListTile(
                        icon: Icons.send_outlined,
                        iconColor: const Color(0xFFF48C06),
                        iconBgColor: const Color(0xFFFFF4E5),
                        title: 'Send Backup via Telegram',
                        subtitle: 'Send database backup to Telegram Bot',
                        onTap: () => _showTelegramSetupDialog(provider),
                      ),
                    ],
                  ),
                ),
                
                _buildSectionHeader('Support & About'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildListTile(
                        icon: Icons.help_outline,
                        iconColor: const Color(0xFF1976D2),
                        iconBgColor: const Color(0xFFE3F2FD),
                        title: 'Help & Support',
                        subtitle: 'Get help and contact support',
                        onTap: () {
                           showDialog(
                             context: context,
                             builder: (_) => AlertDialog(
                               title: const Text('Developer Info'),
                               content: const Text('Developed by: Md Mim Shifat\nEmail: mdshifat.official.05@gmail.com'),
                               actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                             )
                           );
                        },
                      ),
                      const Divider(height: 1, indent: 64),
                      _buildListTile(
                        icon: Icons.info_outline,
                        iconColor: const Color(0xFF7B1FA2),
                        iconBgColor: const Color(0xFFF3E5F5),
                        title: 'About App',
                        subtitle: 'App version and information',
                        trailing: const Text('v1.0.0', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        onTap: () {},
                      ),
                    ],
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
                          color: Colors.black54,
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
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
