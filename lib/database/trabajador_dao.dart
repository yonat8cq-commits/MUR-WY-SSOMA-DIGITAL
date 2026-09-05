import 'app_database.dart';

class TrabajadorDao {
  Future<int> create(Map<String, dynamic> trabajador) async {
    final db = await AppDatabase.instance.database;
    return db.insert('trabajadores', trabajador);
  }

  Future<List<Map<String, dynamic>>> findAll() async {
    final db = await AppDatabase.instance.database;
    return db.query('trabajadores');
  }
}
