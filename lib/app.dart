import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/student/presentation/screens/student_list_screen.dart';
import 'features/batch/presentation/screens/batch_list_screen.dart';
import 'features/exam/presentation/screens/exam_list_screen.dart';
import 'features/fee/presentation/screens/fee_overview_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/notes/presentation/screens/note_list_screen.dart';

import 'features/backup/presentation/screens/backup_settings_screen.dart';
import 'splash_screen.dart';

class CoachingApp extends StatelessWidget {
  const CoachingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coaching Management',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/notes': (context) => const NoteListScreen(),
        '/backup': (context) => const BackupSettingsScreen(),
      },
    );
  }
}

// Temporary Main Navigation to show empty screens while building phases
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const StudentListScreen(),
    const FeeOverviewScreen(),
    const ExamListScreen(),
    const BatchListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coaching App'),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Students'),
          BottomNavigationBarItem(icon: Icon(Icons.monetization_on), label: 'Fees'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Exams'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
