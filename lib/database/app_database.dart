import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();

  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mur_wy_ssoma.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE trabajadores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            dni TEXT,
            nombres TEXT,
            cargo TEXT,
            area TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE capacitaciones (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            curso TEXT,
            fecha TEXT,
            instructor TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE inspecciones (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fecha TEXT,
            area TEXT,
            hallazgo TEXT,
            accion TEXT
          )
        ''');

        await _createOfflineTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createOfflineTables(db);
        }
      },
    );
  }

  Future<void> _createOfflineTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS consentimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dni TEXT NOT NULL,
        version TEXT NOT NULL,
        accepted_at TEXT NOT NULL,
        signature_png BLOB NOT NULL,
        sync_status INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS confirmaciones_capacitacion (
        record_key TEXT PRIMARY KEY,
        dni TEXT NOT NULL,
        training_key TEXT NOT NULL,
        confirmed_at TEXT NOT NULL,
        signature_png BLOB NOT NULL,
        sync_status INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
}
