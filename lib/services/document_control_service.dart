import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'audit_service.dart';
import 'sync_outbox_service.dart';

class DocumentControl {
  final String trainingKey;
  final DateTime deadline;
  final String storedStatus;
  final String? closedAt;
  final int version;

  const DocumentControl({
    required this.trainingKey,
    required this.deadline,
    required this.storedStatus,
    required this.closedAt,
    required this.version,
  });

  String statusFor({required int total, required int signed}) {
    if (storedStatus == 'CERRADO') return 'CERRADO';
    if (total > 0 && signed >= total) return 'COMPLETO';
    if (DateTime.now().isAfter(deadline)) return 'VENCIDO';
    return 'EN FIRMA';
  }

  bool get isClosed => storedStatus == 'CERRADO';
  bool get isExpired => DateTime.now().isAfter(deadline);
}

class RecordVersion {
  final int version;
  final String action;
  final String reason;
  final String createdAt;

  const RecordVersion({
    required this.version,
    required this.action,
    required this.reason,
    required this.createdAt,
  });
}

class DocumentControlService {
  Future<DocumentControl> load(
    String trainingKey,
    String trainingDate,
  ) async {
    final db = await AppDatabase.instance.database;
    var rows = await db.query(
      'control_documental',
      where: 'training_key = ?',
      whereArgs: [trainingKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert(
        'control_documental',
        {
          'training_key': trainingKey,
          'deadline': _deadlineFor(trainingDate).toIso8601String(),
          'status': 'EN_FIRMA',
          'current_version': 0,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      rows = await db.query(
        'control_documental',
        where: 'training_key = ?',
        whereArgs: [trainingKey],
        limit: 1,
      );
    }
    final row = rows.first;
    return DocumentControl(
      trainingKey: trainingKey,
      deadline: DateTime.parse(row['deadline'] as String),
      storedStatus: row['status'] as String? ?? 'EN_FIRMA',
      closedAt: row['closed_at'] as String?,
      version: row['current_version'] as int? ?? 0,
    );
  }

  Future<void> close(String trainingKey, String trainingDate) async {
    final db = await AppDatabase.instance.database;
    final control = await load(trainingKey, trainingDate);
    if (control.isClosed) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final nextVersion = control.version + 1;
    await db.transaction((transaction) async {
      await transaction.update(
        'control_documental',
        {
          'status': 'CERRADO',
          'closed_at': now,
          'closed_by': 'CUTIPA QUISPE JHONATHAN',
          'current_version': nextVersion,
          'updated_at': now,
        },
        where: 'training_key = ?',
        whereArgs: [trainingKey],
      );
      await transaction.insert('versiones_registro', {
        'training_key': trainingKey,
        'version': nextVersion,
        'action': 'CIERRE',
        'reason': 'Registro cerrado por el administrador.',
        'created_at': now,
        'created_by': 'CUTIPA QUISPE JHONATHAN',
      });
    });
    await AuditService().record(
      category: 'DOCUMENTOS',
      action: 'REGISTRO CERRADO',
      detail: 'Se cerró definitivamente el registro de capacitación, versión $nextVersion.',
      targetType: 'CAPACITACIÓN',
      targetId: trainingKey,
    );
    await SyncOutboxService().enqueue(
      entityType: 'DOCUMENT_CONTROL',
      entityId: trainingKey,
      operation: 'CLOSE',
      payload: {'training_id': trainingKey, 'status': 'CERRADO', 'version': nextVersion},
    );
  }

  Future<void> reopen(
    String trainingKey,
    String trainingDate,
    String reason,
  ) async {
    final db = await AppDatabase.instance.database;
    final control = await load(trainingKey, trainingDate);
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((transaction) async {
      await transaction.update(
        'control_documental',
        {
          'status': 'EN_FIRMA',
          'closed_at': null,
          'closed_by': null,
          'updated_at': now,
        },
        where: 'training_key = ?',
        whereArgs: [trainingKey],
      );
      await transaction.insert('versiones_registro', {
        'training_key': trainingKey,
        'version': control.version,
        'action': 'REAPERTURA',
        'reason': reason,
        'created_at': now,
        'created_by': 'CUTIPA QUISPE JHONATHAN',
      });
    });
    await AuditService().record(
      category: 'DOCUMENTOS',
      action: 'REGISTRO REABIERTO',
      detail: 'Motivo: $reason',
      targetType: 'CAPACITACIÓN',
      targetId: trainingKey,
    );
    await SyncOutboxService().enqueue(
      entityType: 'DOCUMENT_CONTROL',
      entityId: trainingKey,
      operation: 'REOPEN',
      payload: {'training_id': trainingKey, 'status': 'EN_FIRMA', 'reason': reason},
    );
  }

  Future<List<RecordVersion>> history(String trainingKey) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'versiones_registro',
      where: 'training_key = ?',
      whereArgs: [trainingKey],
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (row) => RecordVersion(
            version: row['version'] as int? ?? 0,
            action: row['action'] as String? ?? '',
            reason: row['reason'] as String? ?? '',
            createdAt: row['created_at'] as String? ?? '',
          ),
        )
        .toList();
  }

  DateTime _deadlineFor(String value) {
    final normalized = value.trim();
    final direct = DateTime.tryParse(normalized);
    if (direct != null) return direct.add(const Duration(days: 40));
    final parts = normalized.split(RegExp(r'[/.-]'));
    if (parts.length >= 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day).add(const Duration(days: 40));
      }
    }
    return DateTime.now().add(const Duration(days: 40));
  }
}
