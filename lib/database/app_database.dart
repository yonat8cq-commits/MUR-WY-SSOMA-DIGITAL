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
      version: 4,
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
        await _createImportTables(db);
        await _createAuthorizedSignatureTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createOfflineTables(db);
        }
        if (oldVersion < 3) {
          await _createImportTables(db);
        }
        if (oldVersion < 4) {
          await _createAuthorizedSignatureTables(db);
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

  Future<void> _createImportTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS importaciones_tecsup (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        total_rows INTEGER NOT NULL,
        approved_rows INTEGER NOT NULL,
        excluded_rows INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS trabajadores_importados (
        dni TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        company TEXT,
        area TEXT,
        position TEXT,
        account_status TEXT NOT NULL DEFAULT 'TEMPORAL',
        requires_password_change INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS capacitaciones_importadas (
        training_key TEXT PRIMARY KEY,
        course TEXT NOT NULL,
        training_date TEXT NOT NULL,
        approved_participants INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'BORRADOR',
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS participantes_capacitacion (
        training_key TEXT NOT NULL,
        dni TEXT NOT NULL,
        signature_status TEXT NOT NULL DEFAULT 'PENDIENTE',
        assigned_at TEXT NOT NULL,
        PRIMARY KEY (training_key, dni)
      )
    ''');
  }

  Future<void> _createAuthorizedSignatureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS firmas_autorizadas (
        signer_id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        position TEXT NOT NULL,
        signer_role TEXT NOT NULL,
        signature_png BLOB,
        active INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS firmantes_capacitacion (
        training_key TEXT PRIMARY KEY,
        trainer_id TEXT,
        responsible_id TEXT NOT NULL DEFAULT 'jhonathan',
        updated_at TEXT NOT NULL
      )
    ''');
    final now = DateTime.now().toUtc().toIso8601String();
    final defaults = [
      {
        'signer_id': 'roly',
        'full_name': 'ROLY QUISPE TURPO',
        'position': 'SUPERVISOR SSOMA',
        'signer_role': 'CAPACITADOR',
      },
      {
        'signer_id': 'karina',
        'full_name': 'KARINA HERMOSA CASTILLO CORDOVA',
        'position': 'SUPERVISOR SSOMA',
        'signer_role': 'CAPACITADOR',
      },
      {
        'signer_id': 'jhonathan',
        'full_name': 'CUTIPA QUISPE JHONATHAN',
        'position': 'ASISTENTE SSOMA',
        'signer_role': 'RESPONSABLE',
      },
    ];
    for (final signer in defaults) {
      await db.insert(
        'firmas_autorizadas',
        {...signer, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}
