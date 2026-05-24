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
      version: 3,
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
        student_type TEXT NOT NULL,
        monthly_fee REAL NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        monthly_fee REAL NOT NULL DEFAULT 0.0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE enrollments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        join_date TEXT NOT NULL,
        leave_date TEXT,
        discount_amount REAL NOT NULL DEFAULT 0.0,
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
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        due_amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fee_record_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (fee_record_id) REFERENCES fee_records (id) ON DELETE CASCADE,
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
