import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/'); // Or pop to root
            },
          ),
          ListTile(
            leading: const Icon(Icons.class_),
            title: const Text('Batches'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/batches');
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
        ],
      ),
    );
  }
}
