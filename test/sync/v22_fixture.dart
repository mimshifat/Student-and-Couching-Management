/// Exact schema of database version 22 (the last version before cloud sync),
/// used to test the v22 -> v23 upgrade path that existing users will take.
library;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> createV22Schema(Database db) async {
  await db.execute('''
    CREATE TABLE students (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL, phone TEXT, guardian_name TEXT, guardian_phone TEXT,
      guardian_relation TEXT, school_college TEXT, class_name TEXT, roll_number INTEGER,
      address TEXT, notes TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT
    )''');
  await db.execute('''
    CREATE TABLE batches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL, description TEXT, start_time TEXT, end_time TEXT, schedule_days TEXT,
      time_slot TEXT, monthly_fee REAL NOT NULL DEFAULT 0.0, is_active INTEGER NOT NULL DEFAULT 1,
      is_deleted INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL
    )''');
  await db.execute('''
    CREATE TABLE batch_inactive_periods (
      id INTEGER PRIMARY KEY AUTOINCREMENT, batch_id INTEGER NOT NULL, start_date TEXT NOT NULL,
      end_date TEXT, created_at TEXT NOT NULL,
      FOREIGN KEY (batch_id) REFERENCES batches (id) ON DELETE CASCADE
    )''');
  await db.execute('''
    CREATE TABLE enrollments (
      id INTEGER PRIMARY KEY AUTOINCREMENT, student_id INTEGER NOT NULL, batch_id INTEGER NOT NULL,
      student_class TEXT, batch_name TEXT, batch_schedule_days TEXT, batch_time_slot TEXT,
      join_date TEXT NOT NULL, leave_date TEXT, fee_override REAL, created_at TEXT NOT NULL,
      FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
      FOREIGN KEY (batch_id) REFERENCES batches (id) ON DELETE CASCADE
    )''');
  await db.execute('''
    CREATE TABLE exams (
      id INTEGER PRIMARY KEY AUTOINCREMENT, batch_id INTEGER NOT NULL, title TEXT NOT NULL,
      exam_type TEXT NOT NULL, exam_date TEXT NOT NULL, total_marks REAL NOT NULL,
      batch_snapshot TEXT, created_at TEXT NOT NULL,
      FOREIGN KEY (batch_id) REFERENCES batches (id) ON DELETE CASCADE
    )''');
  await db.execute('''
    CREATE TABLE results (
      id INTEGER PRIMARY KEY AUTOINCREMENT, exam_id INTEGER NOT NULL, student_id INTEGER NOT NULL,
      batch_id INTEGER NOT NULL, obtained_marks REAL, is_absent INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      FOREIGN KEY (exam_id) REFERENCES exams (id) ON DELETE CASCADE,
      FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
      FOREIGN KEY (batch_id) REFERENCES batches (id) ON DELETE CASCADE
    )''');
  await db.execute('''
    CREATE TABLE fee_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT, student_id INTEGER NOT NULL, student_class TEXT,
      batch_id INTEGER, batch_details_snapshot TEXT, month INTEGER NOT NULL, year INTEGER NOT NULL,
      total_amount REAL NOT NULL, paid_amount REAL NOT NULL DEFAULT 0.0,
      is_settled INTEGER NOT NULL DEFAULT 0, note TEXT, payment_date TEXT,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
    )''');
  await db.execute('''
    CREATE TABLE fee_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT, fee_record_id INTEGER NOT NULL, amount REAL NOT NULL,
      payment_date TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL,
      FOREIGN KEY (fee_record_id) REFERENCES fee_records (id) ON DELETE CASCADE
    )''');
  await db.execute('''
    CREATE TABLE routines (
      id INTEGER PRIMARY KEY AUTOINCREMENT, batch_id INTEGER NOT NULL, day_of_week TEXT NOT NULL,
      start_time TEXT NOT NULL, end_time TEXT NOT NULL, subject TEXT NOT NULL, teacher_name TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (batch_id) REFERENCES batches (id) ON DELETE CASCADE
    )''');
  await db.execute('''
    CREATE TABLE notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, content TEXT NOT NULL,
      is_pinned INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
    )''');
  await db.execute('''
    CREATE TABLE backup_settings (
      id INTEGER PRIMARY KEY CHECK (id = 1), telegram_bot_token TEXT, telegram_chat_id TEXT,
      auto_backup_enabled INTEGER NOT NULL DEFAULT 0, last_backup_time TEXT
    )''');
  await db.execute('INSERT INTO backup_settings (id, auto_backup_enabled) VALUES (1, 0)');
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_enrollments_unique ON enrollments(student_id, batch_id) WHERE leave_date IS NULL',
  );
}

/// Inserts a realistic data set of the kind existing users have.
Future<void> seedV22Data(Database db) async {
  const now = '2026-01-01';
  await db.insert('students', {'name': 'Rahim', 'created_at': now, 'updated_at': now});
  await db.insert('students', {'name': 'Karim', 'created_at': now, 'updated_at': now});
  await db.insert('batches', {'name': 'HSC Physics', 'monthly_fee': 1000.0, 'created_at': now});
  await db.insert('batch_inactive_periods', {'batch_id': 1, 'start_date': now, 'created_at': now});
  await db.insert('enrollments', {'student_id': 1, 'batch_id': 1, 'join_date': now, 'created_at': now});
  await db.insert('enrollments', {'student_id': 2, 'batch_id': 1, 'join_date': now, 'created_at': now});
  await db.insert('exams', {
    'batch_id': 1, 'title': 'Monthly 1', 'exam_type': 'Monthly', 'exam_date': now,
    'total_marks': 100.0, 'created_at': now,
  });
  await db.insert('results', {'exam_id': 1, 'student_id': 1, 'batch_id': 1, 'obtained_marks': 80.0, 'created_at': now});
  await db.insert('results', {'exam_id': 1, 'student_id': 2, 'batch_id': 1, 'obtained_marks': 70.0, 'created_at': now});
  for (final m in [1, 2]) {
    await db.insert('fee_records', {
      'student_id': 1, 'batch_id': 1, 'month': m, 'year': 2026, 'total_amount': 1000.0,
      'paid_amount': 500.0, 'created_at': now, 'updated_at': now,
    });
  }
  // A legacy duplicate (same student/batch/month/year) — must not break the
  // deterministic-id backfill.
  await db.insert('fee_records', {
    'student_id': 1, 'batch_id': 1, 'month': 1, 'year': 2026, 'total_amount': 1000.0,
    'paid_amount': 0.0, 'created_at': now, 'updated_at': now,
  });
  // Legacy aggregated record without batch.
  await db.insert('fee_records', {
    'student_id': 2, 'month': 12, 'year': 2025, 'total_amount': 800.0,
    'paid_amount': 800.0, 'created_at': now, 'updated_at': now,
  });
  await db.insert('fee_transactions', {'fee_record_id': 1, 'amount': 500.0, 'payment_date': now, 'created_at': now});
  await db.insert('routines', {
    'batch_id': 1, 'day_of_week': 'Sat', 'start_time': '10:00', 'end_time': '11:00',
    'subject': 'Physics', 'created_at': now,
  });
  await db.insert('notes', {'title': 'Hello', 'content': 'World', 'created_at': now, 'updated_at': now});
}
