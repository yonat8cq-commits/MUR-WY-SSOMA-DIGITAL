import '../database/app_database.dart';
import 'document_control_service.dart';

class WorkerProfile {
  final String dni;
  final String fullName;
  final String company;
  final String area;
  final String position;
  final String accountStatus;
  final bool requiresPasswordChange;

  const WorkerProfile({
    required this.dni,
    required this.fullName,
    required this.company,
    required this.area,
    required this.position,
    required this.accountStatus,
    required this.requiresPasswordChange,
  });

  bool get active => accountStatus != 'INACTIVO';
}

class AssignedTraining {
  final String key;
  final String course;
  final String date;
  final bool signed;
  final String status;
  final DateTime deadline;

  const AssignedTraining({
    required this.key,
    required this.course,
    required this.date,
    required this.signed,
    required this.status,
    required this.deadline,
  });

  bool get canSign => !signed && status != 'CERRADO' && status != 'VENCIDO';
}

class WorkerDataService {
  Future<bool> hasImportedWorkers() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM trabajadores_importados',
    );
    return (rows.first['total'] as int? ?? 0) > 0;
  }

  Future<bool> workerExists(String dni) async =>
      await loadProfile(dni) != null;

  Future<WorkerProfile?> loadProfile(String dni) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'trabajadores_importados',
      where: 'dni = ?',
      whereArgs: [dni],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return WorkerProfile(
      dni: dni,
      fullName: row['full_name'] as String? ?? '',
      company: row['company'] as String? ?? '',
      area: row['area'] as String? ?? '',
      position: row['position'] as String? ?? '',
      accountStatus: row['account_status'] as String? ?? 'TEMPORAL',
      requiresPasswordChange:
          (row['requires_password_change'] as int? ?? 1) == 1,
    );
  }

  Future<List<AssignedTraining>> loadTrainings(String dni) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        c.training_key,
        c.course,
        c.training_date,
        CASE WHEN f.record_key IS NULL THEN 0 ELSE 1 END AS signed
      FROM participantes_capacitacion p
      INNER JOIN capacitaciones_importadas c
        ON c.training_key = p.training_key
      LEFT JOIN confirmaciones_capacitacion f
        ON f.training_key = p.training_key AND f.dni = p.dni
      WHERE p.dni = ? AND c.status != 'ARCHIVADO'
      ORDER BY c.training_date DESC, c.course ASC
      ''',
      [dni],
    );
    final result = <AssignedTraining>[];
    final documentService = DocumentControlService();
    for (final row in rows) {
      final key = row['training_key'] as String;
      final date = row['training_date'] as String? ?? '';
      final signed = (row['signed'] as int? ?? 0) == 1;
      final control = await documentService.load(key, date);
      result.add(
        AssignedTraining(
          key: key,
          course: row['course'] as String? ?? '',
          date: date,
          signed: signed,
          status: control.isClosed
              ? 'CERRADO'
              : control.isExpired
                  ? 'VENCIDO'
                  : signed
                      ? 'FIRMADO'
                      : 'EN FIRMA',
          deadline: control.deadline,
        ),
      );
    }
    return result;
  }
}
