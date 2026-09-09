import '../database/app_database.dart';

class TrainingProgress {
  final String key;
  final String course;
  final String date;
  final int total;
  final int signed;

  const TrainingProgress({
    required this.key,
    required this.course,
    required this.date,
    required this.total,
    required this.signed,
  });

  int get pending => total - signed;
  double get ratio => total == 0 ? 0 : signed / total;
}

class ParticipantProgress {
  final String dni;
  final String fullName;
  final String position;
  final bool signed;

  const ParticipantProgress({
    required this.dni,
    required this.fullName,
    required this.position,
    required this.signed,
  });
}

class AdminTrackingService {
  Future<List<TrainingProgress>> loadTrainings() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT
        c.training_key,
        c.course,
        c.training_date,
        COUNT(p.dni) AS total,
        SUM(CASE WHEN f.record_key IS NULL THEN 0 ELSE 1 END) AS signed
      FROM capacitaciones_importadas c
      LEFT JOIN participantes_capacitacion p
        ON p.training_key = c.training_key
      LEFT JOIN confirmaciones_capacitacion f
        ON f.training_key = p.training_key AND f.dni = p.dni
      GROUP BY c.training_key, c.course, c.training_date
      ORDER BY c.training_date DESC, c.course ASC
    ''');
    return rows
        .map(
          (row) => TrainingProgress(
            key: row['training_key'] as String,
            course: row['course'] as String? ?? '',
            date: row['training_date'] as String? ?? '',
            total: row['total'] as int? ?? 0,
            signed: row['signed'] as int? ?? 0,
          ),
        )
        .toList();
  }

  Future<List<ParticipantProgress>> loadParticipants(String trainingKey) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        p.dni,
        w.full_name,
        w.position,
        CASE WHEN f.record_key IS NULL THEN 0 ELSE 1 END AS signed
      FROM participantes_capacitacion p
      INNER JOIN trabajadores_importados w ON w.dni = p.dni
      LEFT JOIN confirmaciones_capacitacion f
        ON f.training_key = p.training_key AND f.dni = p.dni
      WHERE p.training_key = ?
      ORDER BY w.full_name ASC
      ''',
      [trainingKey],
    );
    return rows
        .map(
          (row) => ParticipantProgress(
            dni: row['dni'] as String,
            fullName: row['full_name'] as String? ?? '',
            position: row['position'] as String? ?? '',
            signed: (row['signed'] as int? ?? 0) == 1,
          ),
        )
        .toList();
  }
}
