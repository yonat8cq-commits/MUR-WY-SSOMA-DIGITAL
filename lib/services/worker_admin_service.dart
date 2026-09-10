import '../database/app_database.dart';
import 'audit_service.dart';
import 'sync_outbox_service.dart';

class WorkerAdminItem {
  final String dni;
  final String fullName;
  final String company;
  final String area;
  final String position;
  final String accountStatus;
  final bool requiresPasswordChange;
  final int trainings;
  final int signed;

  const WorkerAdminItem({
    required this.dni,
    required this.fullName,
    required this.company,
    required this.area,
    required this.position,
    required this.accountStatus,
    required this.requiresPasswordChange,
    required this.trainings,
    required this.signed,
  });

  bool get active => accountStatus != 'INACTIVO';
}

class WorkerAdminService {
  static const temporaryPassword = 'MurWy2026';

  Future<List<WorkerAdminItem>> loadWorkers() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT w.dni, w.full_name, w.company, w.area, w.position,
             w.account_status, w.requires_password_change,
             COUNT(DISTINCT p.training_key) AS trainings,
             COUNT(DISTINCT f.record_key) AS signed
      FROM trabajadores_importados w
      LEFT JOIN participantes_capacitacion p ON p.dni = w.dni
      LEFT JOIN confirmaciones_capacitacion f
        ON f.dni = w.dni AND f.training_key = p.training_key
      GROUP BY w.dni, w.full_name, w.company, w.area, w.position,
               w.account_status, w.requires_password_change
      ORDER BY w.full_name ASC
    ''');
    return rows
        .map(
          (row) => WorkerAdminItem(
            dni: row['dni'] as String,
            fullName: row['full_name'] as String? ?? '',
            company: row['company'] as String? ?? '',
            area: row['area'] as String? ?? '',
            position: row['position'] as String? ?? '',
            accountStatus: row['account_status'] as String? ?? 'TEMPORAL',
            requiresPasswordChange:
                (row['requires_password_change'] as int? ?? 1) == 1,
            trainings: row['trainings'] as int? ?? 0,
            signed: row['signed'] as int? ?? 0,
          ),
        )
        .toList();
  }

  Future<void> setActive(String dni, bool active) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'trabajadores_importados',
      {
        'account_status': active ? 'ACTIVO' : 'INACTIVO',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'dni = ?',
      whereArgs: [dni],
    );
    await AuditService().record(
      category: 'USUARIOS',
      action: active ? 'TRABAJADOR ACTIVADO' : 'TRABAJADOR DESACTIVADO',
      detail: 'Se cambió el estado de acceso del trabajador con DNI $dni.',
      targetType: 'TRABAJADOR',
      targetId: dni,
    );
    await SyncOutboxService().enqueue(
      entityType: 'WORKER',
      entityId: dni,
      operation: 'STATUS',
      payload: {'dni': dni, 'account_status': active ? 'ACTIVO' : 'INACTIVO'},
    );
  }

  Future<void> resetTemporaryPassword(String dni) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((transaction) async {
      await transaction.update(
        'trabajadores_importados',
        {
          'requires_password_change': 1,
          'password_hash': null,
          'password_salt': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'dni = ?',
        whereArgs: [dni],
      );
      await transaction.delete(
        'app_settings',
        where: 'setting_key = ?',
        whereArgs: ['password_changed_$dni'],
      );
    });
    await AuditService().record(
      category: 'USUARIOS',
      action: 'CONTRASEÑA TEMPORAL RESTABLECIDA',
      detail: 'El trabajador deberá crear una nueva contraseña en su próximo ingreso.',
      targetType: 'TRABAJADOR',
      targetId: dni,
    );
    await SyncOutboxService().enqueue(
      entityType: 'WORKER',
      entityId: dni,
      operation: 'PASSWORD_RESET_REQUIRED',
      payload: {'dni': dni, 'requires_password_change': true},
    );
  }
}
