import 'app_database.dart';

class InspeccionDao {
  Future<int> create(Map<String, dynamic> inspeccion) async {
    final db = await AppDatabase.instance.database;
    return db.insert('inspecciones', inspeccion);
  }

  Future<List<Map<String, dynamic>>> findAll() async {
    final db = await AppDatabase.instance.database;
    return db.query('inspecciones');
  }
}
