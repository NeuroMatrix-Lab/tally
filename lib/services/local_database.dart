import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static Database? _db;

  static Future<Database> get() async {
    if (_db != null) return _db!;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'tally.db');

    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _initialize(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < newVersion) {
          await _initialize(db);
        }
      },
      onDowngrade: onDatabaseDowngradeDelete,
    );

    return _db!;
  }

  static Future<void> _initialize(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS records (
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL UNIQUE,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        work_content TEXT NOT NULL,
        amount REAL NOT NULL,
        ledger TEXT NOT NULL,
        image_url TEXT,
        staff_ids TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        deleted_at TEXT DEFAULT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS deleted_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id TEXT NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        work_content TEXT NOT NULL,
        amount REAL NOT NULL,
        ledger TEXT NOT NULL,
        image_url TEXT,
        staff_ids TEXT,
        deleted_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ledgers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS staff (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.insert('ledgers', {
      'name': '默认账本',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
