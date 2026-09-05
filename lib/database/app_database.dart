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
      version: 1,
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
      },
    );
  }
}
