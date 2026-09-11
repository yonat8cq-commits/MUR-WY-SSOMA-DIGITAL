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
      version: 10,
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
        await _createDocumentControlTables(db);
        await _createCompanyTables(db);
        await _createHistoricalDocumentTables(db);
        await _createAuditTables(db);
        await _createSyncTables(db);
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
        if (oldVersion < 5) {
          await _createDocumentControlTables(db);
        }
        if (oldVersion < 6) {
          await _createCompanyTables(db);
        }
        if (oldVersion < 7) {
          await _createHistoricalDocumentTables(db);
        }
        if (oldVersion < 8) {
          await _addWorkerCredentials(db);
        }
        if (oldVersion < 9) {
          await _createAuditTables(db);
        }
        if (oldVersion < 10) {
          await _createSyncTables(db);
        }
      },
    );
  }

  Future<void> _createSyncTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        synced_at TEXT,
        UNIQUE(entity_type, entity_id, operation)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        collection_name TEXT PRIMARY KEY,
        last_pulled_at TEXT,
        last_success_at TEXT,
        last_error TEXT
      )
    ''');
  }

  Future<void> _createAuditTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS auditoria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        occurred_at TEXT NOT NULL,
        actor TEXT NOT NULL,
        category TEXT NOT NULL,
        action TEXT NOT NULL,
        detail TEXT NOT NULL,
        target_type TEXT,
        target_id TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_auditoria_fecha
      ON auditoria(occurred_at DESC)
    ''');
  }

  Future<void> _addWorkerCredentials(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(trabajadores_importados)');
    final names = columns.map((column) => column['name']).toSet();
    if (!names.contains('password_hash')) {
      await db.execute(
        'ALTER TABLE trabajadores_importados ADD COLUMN password_hash TEXT',
      );
    }
    if (!names.contains('password_salt')) {
      await db.execute(
        'ALTER TABLE trabajadores_importados ADD COLUMN password_salt TEXT',
      );
    }
    await db.update(
      'trabajadores_importados',
      {'requires_password_change': 1},
      where: 'password_hash IS NULL OR password_salt IS NULL',
    );
  }

  Future<void> _createHistoricalDocumentTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS documentos_historicos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        course TEXT NOT NULL,
        training_date TEXT NOT NULL,
        company TEXT NOT NULL,
        file_name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        file_bytes BLOB NOT NULL,
        imported_at TEXT NOT NULL
      )
    ''');
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
        password_hash TEXT,
        password_salt TEXT,
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

  Future<void> _createDocumentControlTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS control_documental (
        training_key TEXT PRIMARY KEY,
        deadline TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'EN_FIRMA',
        closed_at TEXT,
        closed_by TEXT,
        current_version INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS versiones_registro (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        training_key TEXT NOT NULL,
        version INTEGER NOT NULL,
        action TEXT NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT NOT NULL,
        UNIQUE(training_key, version, action)
      )
    ''');
  }

  Future<void> _createCompanyTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS empresas (
        company_id TEXT PRIMARY KEY,
        business_name TEXT NOT NULL,
        ruc TEXT,
        address TEXT,
        economic_activity TEXT,
        employee_count INTEGER NOT NULL DEFAULT 0,
        logo_png BLOB,
        active INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS empresa_capacitacion (
        training_key TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        assigned_at TEXT NOT NULL
      )
    ''');
    await db.insert(
      'empresas',
      {
        'company_id': 'mur_wy',
        'business_name': 'MUR WY S.A.C.',
        'ruc': '20470407442',
        'address':
            'AV. MALECÓN CHECA NRO. 3777 URB. CAMPOY - SAN JUAN DE LURIGANCHO - LIMA',
        'economic_activity': 'MINERÍA',
        'employee_count': 0,
        'active': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
