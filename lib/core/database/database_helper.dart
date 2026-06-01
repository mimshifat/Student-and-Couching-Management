import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'coaching_app.db');
    return await openDatabase(
      path,
      version: 17,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE batches ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE students ADD COLUMN student_type TEXT NOT NULL DEFAULT \'Normal\'');
      await db.execute('ALTER TABLE students ADD COLUMN guardian_relation TEXT');
    }
    if (oldVersion < 4) {
      // 1. Drop payments table
      await db.execute('DROP TABLE IF EXISTS payments');
      
      // 2. Recreate fee_records
      await db.execute('''
        CREATE TABLE fee_records_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          month INTEGER NOT NULL,
          year INTEGER NOT NULL,
          total_amount REAL NOT NULL,
          paid_amount REAL NOT NULL DEFAULT 0.0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('INSERT INTO fee_records_new (id, student_id, month, year, total_amount, paid_amount, created_at, updated_at) SELECT id, student_id, month, year, total_amount, paid_amount, created_at, updated_at FROM fee_records');
      await db.execute('DROP TABLE fee_records');
      await db.execute('ALTER TABLE fee_records_new RENAME TO fee_records');

      // 3. Recreate enrollments
      await db.execute('''
        CREATE TABLE enrollments_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          batch_id INTEGER NOT NULL,
          join_date TEXT NOT NULL,
          leave_date TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
          FOREIGN KEY (batch_id) REFERENCES batches (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('INSERT INTO enrollments_new (id, student_id, batch_id, join_date, leave_date, created_at) SELECT id, student_id, batch_id, join_date, leave_date, created_at FROM enrollments');
      await db.execute('DROP TABLE enrollments');
      await db.execute('ALTER TABLE enrollments_new RENAME TO enrollments');

      // 4. Recreate students
      await db.execute('''
        CREATE TABLE students_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          guardian_name TEXT,
          guardian_phone TEXT,
          guardian_relation TEXT,
          school_college TEXT,
          class_name TEXT,
          roll_number INTEGER,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('INSERT INTO students_new (id, name, phone, guardian_name, guardian_phone, guardian_relation, school_college, class_name, roll_number, created_at, updated_at) SELECT id, name, phone, guardian_name, guardian_phone, guardian_relation, school_college, class_name, roll_number, created_at, updated_at FROM students');
      await db.execute('DROP TABLE students');
      await db.execute('ALTER TABLE students_new RENAME TO students');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE notes ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE students ADD COLUMN address TEXT');
      await db.execute('ALTER TABLE students ADD COLUMN notes TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE enrollments ADD COLUMN fee_override REAL');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE fee_records ADD COLUMN student_class TEXT');
      await db.execute('ALTER TABLE enrollments ADD COLUMN student_class TEXT');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE batches ADD COLUMN start_time TEXT');
      await db.execute('ALTER TABLE batches ADD COLUMN end_time TEXT');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE batches ADD COLUMN schedule_days TEXT');
      await db.execute('ALTER TABLE batches ADD COLUMN time_slot TEXT');
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE enrollments ADD COLUMN batch_name TEXT');
      await db.execute('ALTER TABLE enrollments ADD COLUMN batch_schedule_days TEXT');
      await db.execute('ALTER TABLE enrollments ADD COLUMN batch_time_slot TEXT');
      await db.execute('ALTER TABLE fee_records ADD COLUMN batch_details_snapshot TEXT');
    }
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE fee_records ADD COLUMN batch_id INTEGER REFERENCES batches(id) ON DELETE SET NULL');
    }
    if (oldVersion < 13) {
      await db.execute('ALTER TABLE fee_records ADD COLUMN is_settled INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 14) {
      await db.execute('ALTER TABLE exams ADD COLUMN exam_type TEXT NOT NULL DEFAULT \'Monthly\'');
    }
    if (oldVersion < 15) {
      await db.execute('ALTER TABLE fee_records ADD COLUMN note TEXT');
    }
    if (oldVersion < 16) {
      await db.execute('ALTER TABLE fee_records ADD COLUMN payment_date TEXT');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_enrollments_unique ON enrollments(student_id, batch_id) WHERE leave_date IS NULL');
    }
    if (oldVersion < 17) {
      await db.execute('''
        CREATE TABLE batch_inactive_periods (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          batch_id INTEGER NOT NULL,
          start_date TEXT NOT NULL,
          end_date TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (batch_id) REFERENCES batches (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        guardian_name TEXT,
        guardian_phone TEXT,
        guardian_relation TEXT,
        school_college TEXT,
        class_name TEXT,
        roll_number INTEGER,
        address TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        start_time TEXT,
        end_time TEXT,
        schedule_days TEXT,
        time_slot TEXT,
        monthly_fee REAL NOT NULL DEFAULT 0.0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE batch_inactive_periods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (batch_id) REFERENCES batches (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE enrollments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        student_class TEXT,
        batch_name TEXT,
        batch_schedule_days TEXT,
        batch_time_slot TEXT,
        join_date TEXT NOT NULL,
        leave_date TEXT,
        fee_override REAL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (batch_id) REFERENCES batches (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE exams (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        exam_type TEXT NOT NULL,
        exam_date TEXT NOT NULL,
        total_marks REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (batch_id) REFERENCES batches (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exam_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        obtained_marks REAL,
        is_absent INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (exam_id) REFERENCES exams (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (batch_id) REFERENCES batches (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE fee_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        student_class TEXT,
        batch_id INTEGER,
        batch_details_snapshot TEXT,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        is_settled INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        payment_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        day_of_week TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        subject TEXT NOT NULL,
        teacher_name TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (batch_id) REFERENCES batches (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE backup_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        telegram_bot_token TEXT,
        telegram_chat_id TEXT,
        auto_backup_enabled INTEGER NOT NULL DEFAULT 0,
        last_backup_time TEXT
      )
    ''');

    // Insert default row for backup_settings
    await db.execute('''
      INSERT INTO backup_settings (id, auto_backup_enabled) VALUES (1, 0)
    ''');

    // Create unique index for enrollments
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_enrollments_unique ON enrollments(student_id, batch_id) WHERE leave_date IS NULL');
  }

  Future<String> getDatabasePathStr() async {
    return join(await getDatabasesPath(), 'coaching_app.db');
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Resets the cached database connection so the next access re-opens the file.
  /// Used after an import to pick up the newly copied database.
  void resetInstance() {
    _database = null;
  }
}
