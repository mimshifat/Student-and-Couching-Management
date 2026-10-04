import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/database/database_helper.dart';

import 'features/student/data/repositories/student_repository_impl.dart';
import 'features/student/presentation/providers/student_provider.dart';
import 'features/batch/data/repositories/batch_repository_impl.dart';
import 'features/batch/presentation/providers/batch_provider.dart';
import 'features/enrollment/data/repositories/enrollment_repository_impl.dart';
import 'features/enrollment/presentation/providers/enrollment_provider.dart';

import 'features/fee/data/repositories/fee_repository_impl.dart';
import 'features/fee/presentation/providers/fee_provider.dart';
import 'features/exam/data/repositories/exam_repository_impl.dart';
import 'features/exam/presentation/providers/exam_provider.dart';

import 'features/routine/data/repositories/routine_repository_impl.dart';
import 'features/routine/presentation/providers/routine_provider.dart';
import 'features/notes/data/repositories/note_repository_impl.dart';
import 'features/notes/presentation/providers/note_provider.dart';

import 'package:workmanager/workmanager.dart';
import 'features/backup/data/repositories/backup_repository_impl.dart';
import 'features/backup/presentation/providers/backup_provider.dart';
import 'features/enrollment/presentation/providers/annual_report_provider.dart';
import 'features/enrollment/data/repositories/enrollment_repository_impl.dart' show EnrollmentRepositoryImpl;
import 'features/auth/presentation/providers/auth_provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'core/sync/sync_engine.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == "cloudSyncTask") {
        // Ensure Firebase is initialized for background execution
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        }
        
        // Initialize Database explicitly in background
        await DatabaseHelper().database;
        
        final engine = SyncEngine();
        await engine.runSync();
        return Future.value(true);
      }

      if (task == "dailyBackupTask") {
        final repo = BackupRepositoryImpl();
        final settings = await repo.getSettings();

        if (!settings.autoBackupEnabled) return Future.value(true);

        // Only run if Telegram is actually configured
        final token = settings.telegramBotToken?.trim() ?? '';
        final chatId = settings.telegramChatId?.trim() ?? '';
        if (token.isEmpty || chatId.isEmpty) return Future.value(true);

        // Time guard: only send if 23+ hours have passed since last backup.
        final lastBackup = settings.lastBackupTime;
        if (lastBackup != null) {
          final hoursSinceLast = DateTime.now().difference(lastBackup).inHours;
          if (hoursSinceLast < 23) {
            return Future.value(true); // Not time yet — skip silently
          }
        }

        await repo.sendBackupToTelegram(settings);
        return Future.value(true);
      }
      
      return Future.value(true);
    } catch (e) {
      // Return false so Android OS retries with exponential backoff
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  await FirebaseAppCheck.instance.activate();

  // Initialize Database
  await DatabaseHelper().database;

  // Initialize Workmanager
  Workmanager().initialize(
    callbackDispatcher,
  );
  
  // Register cloud sync task (runs roughly every 15 mins by OS scheduling)
  Workmanager().registerPeriodicTask(
    "cloudSync",
    "cloudSyncTask",
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  // Register daily backup task — only runs when network is available
  Workmanager().registerPeriodicTask(
    "dailyBackup",
    "dailyBackupTask",
    frequency: const Duration(hours: 24),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider(StudentRepositoryImpl())),
        ChangeNotifierProvider(create: (_) => BatchProvider(BatchRepositoryImpl())),
        ChangeNotifierProvider(create: (_) => EnrollmentProvider(EnrollmentRepositoryImpl())),
        ChangeNotifierProvider(create: (_) => ExamProvider(ExamRepositoryImpl(), EnrollmentRepositoryImpl())),
        ChangeNotifierProvider(create: (_) => FeeProvider(FeeRepositoryImpl(), StudentRepositoryImpl())),
        ChangeNotifierProvider(create: (_) => RoutineProvider(RoutineRepositoryImpl())),
        ChangeNotifierProvider(create: (_) => NoteProvider(NoteRepositoryImpl())),
        ChangeNotifierProvider(create: (_) => BackupProvider(BackupRepositoryImpl())),
        ChangeNotifierProvider(create: (_) => AnnualReportProvider(EnrollmentRepositoryImpl())),
      ],
      child: const CoachingApp(),
    ),
  );
}
