import 'app_database.dart';

class CapacitacionDao {
  Future<int> create(Map<String, dynamic> capacitacion) async {
    final db = await AppDatabase.instance.database;
    return db.insert('capacitaciones', capacitacion);
  }

  Future<List<Map<String, dynamic>>> findAll() async {
    final db = await AppDatabase.instance.database;
    return db.query('capacitaciones');
  }
}
