import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../sync/sync_restore.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.school, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'Student & Coaching Management',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Exams'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/exams');
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Result Analytics'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/result-analytics');
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Routine'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/routine');
            },
          ),
          ListTile(
            leading: const Icon(Icons.notes),
            title: const Text('My Notes'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.pushNamed(context, '/notes');
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup Settings'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.pushNamed(context, '/backup');
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_rounded),
            title: const Text('Annual Report'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/annual-report');
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: const Text('Restore from Cloud'),
            onTap: () async {
              Navigator.pop(context); // Close drawer
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );
                final restore = SyncRestore();
                await restore.restoreFromCloud();
                if (context.mounted) {
                  Navigator.pop(context); // Pop loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Restore complete! Restarting app may be needed to see changes.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Pop loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restore failed: $e')),
                  );
                }
              }
            },
          ),
          const Divider(),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.user == null) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await auth.signOut();
                  if (context.mounted) {
                    // Navigate back to the login screen by popping everything
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
