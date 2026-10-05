import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class GuideItem {
  final String title;
  final String description;
  final IconData icon;
  final List<GuideStep> steps;

  GuideItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.steps,
  });
}

class GuideStep {
  final String title;
  final String content;
  final IconData? icon;
  final Color? iconColor;

  GuideStep({
    required this.title,
    required this.content,
    this.icon,
    this.iconColor,
  });
}

class GuidesListScreen extends StatelessWidget {
  const GuidesListScreen({super.key});

  static final List<GuideItem> _guides = [
    GuideItem(
      title: 'Telegram Auto Backup Setup',
      description: 'Learn how to automatically send daily database backups to your Telegram.',
      icon: Icons.telegram,
      steps: [
        GuideStep(
          title: 'Step 1: Open BotFather',
          content: 'Open the Telegram app and search for "@BotFather". Tap on the official verified bot and press "Start".',
          icon: Icons.search,
          iconColor: Colors.blue,
        ),
        GuideStep(
          title: 'Step 2: Create a New Bot',
          content: 'Send the command /newbot. BotFather will ask you for a name (e.g., "My App Backup") and a unique username ending in "bot" (e.g., "my_backup_123_bot").',
          icon: Icons.add_circle_outline,
          iconColor: Colors.green,
        ),
        GuideStep(
          title: 'Step 3: Copy the Bot Token',
          content: 'BotFather will give you a long HTTP API Token (it looks like 123456:ABC-DEF1234...). Copy this entire text—this is your "Bot Token".',
          icon: Icons.content_copy,
          iconColor: Colors.orange,
        ),
        GuideStep(
          title: 'Step 4: Start Your Bot',
          content: 'Tap the link to your new bot that BotFather gave you (e.g., t.me/my_backup_123_bot) and press "Start" so it can message you.',
          icon: Icons.play_arrow_rounded,
          iconColor: Colors.purple,
        ),
        GuideStep(
          title: 'Step 5: Get your Chat ID',
          content: 'Search for "@userinfobot" in Telegram and start it. It will reply with your "Id" (a number like 123456789). Copy this—this is your "Chat ID".',
          icon: Icons.person_search,
          iconColor: Colors.teal,
        ),
        GuideStep(
          title: 'Step 6: Configure the App',
          content: 'Come back to this app, go to Settings > Telegram Backup, and paste your Bot Token and Chat ID. Press Save!',
          icon: Icons.save,
          iconColor: AppTheme.primaryColor,
        ),
      ],
    ),
    GuideItem(
      title: 'Restoring a Local Backup',
      description: 'How to safely restore your data if you reinstalled the app or lost your data.',
      icon: Icons.restore,
      steps: [
        GuideStep(
          title: 'Step 1: Find your Backup File',
          content: "When you export a backup or get one from Telegram, save the '.db' file to your phone's Downloads folder.",
          icon: Icons.folder,
          iconColor: Colors.amber,
        ),
        GuideStep(
          title: 'Step 2: Go to Settings',
          content: 'Open the app, navigate to Settings, and tap "Restore Database".',
          icon: Icons.settings,
          iconColor: Colors.grey,
        ),
        GuideStep(
          title: 'Step 3: Select the File',
          content: 'A file picker will open. Choose the ".db" file you saved earlier. The app will replace its current data with the backup data instantly.',
          icon: Icons.file_upload,
          iconColor: Colors.blue,
        ),
      ],
    ),
    GuideItem(
      title: 'Managing License & Devices',
      description: 'What happens when you change phones or uninstall the app.',
      icon: Icons.security,
      steps: [
        GuideStep(
          title: 'Reinstalling on the same phone',
          content: 'If you uninstall and reinstall the app on the EXACT same phone, just enter your license key again. It will automatically let you in.',
          icon: Icons.phone_android,
          iconColor: Colors.green,
        ),
        GuideStep(
          title: 'Changing Phones',
          content: 'Your license is locked to your device for security. If you buy a new phone or factory reset, you will see a "Permission Denied" message.',
          icon: Icons.phonelink_erase,
          iconColor: Colors.red,
        ),
        GuideStep(
          title: 'How to switch devices',
          content: 'Send a message to the developer on WhatsApp. They will reset your device lock in 10 seconds, and you can activate your new phone immediately.',
          icon: Icons.support_agent,
          iconColor: Colors.blue,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Guides & Tutorials',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Offline & Backup Benefit Banner
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.15),
                  Colors.blue.shade100,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(Icons.cloud_off_rounded, color: AppTheme.primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why Setup Auto Backup?',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This app is designed to work 100% offline for maximum speed and privacy. However, because it is offline, if you lose your phone or accidentally uninstall the app, your data could be permanently lost!\n\nPlease set up Telegram Auto Backup below to automatically keep your data completely safe.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          ..._guides.map((guide) {
            return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GuideDetailScreen(guide: guide),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(guide.icon, color: AppTheme.primaryColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guide.title,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              guide.description,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          );
          }).toList(),
        ],
      ),
    );
  }
}

class GuideDetailScreen extends StatelessWidget {
  final GuideItem guide;

  const GuideDetailScreen({super.key, required this.guide});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          guide.title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: guide.steps.length,
        itemBuilder: (context, index) {
          final step = guide.steps[index];
          final isLast = index == guide.steps.length - 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline line and icon
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (step.iconColor ?? AppTheme.primaryColor).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (step.iconColor ?? AppTheme.primaryColor).withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: step.icon != null 
                        ? Icon(step.icon, color: step.iconColor ?? AppTheme.primaryColor, size: 20)
                        : Text(
                            '${index + 1}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: step.iconColor ?? AppTheme.primaryColor,
                            ),
                          ),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 60,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Content Card
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step.content,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
