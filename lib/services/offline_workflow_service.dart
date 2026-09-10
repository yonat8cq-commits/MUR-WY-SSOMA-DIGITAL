import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'document_control_service.dart';
import 'sync_outbox_service.dart';

class OfflineWorkflowService {
  static final OfflineWorkflowService instance = OfflineWorkflowService._();
  OfflineWorkflowService._();

  Future<void> openSession(String dni) => _set('current_dni', dni);

  Future<String?> get currentDni => _get('current_dni');

  Future<void> closeSession() => _delete('current_dni');

  Future<void> setSharedDeviceMode(bool enabled) =>
      _set('shared_device_mode', enabled ? 'true' : 'false');

  Future<bool> get sharedDeviceMode async =>
      await _get('shared_device_mode') == 'true';

  Future<bool> passwordWasChanged(String dni) async =>
      await _get('password_changed_$dni') == 'true';

  Future<void> markPasswordChanged(String dni) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'trabajadores_importados',
      {
        'requires_password_change': 0,
        'account_status': 'ACTIVO',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'dni = ?',
      whereArgs: [dni],
    );
    await _set('password_changed_$dni', 'true');
  }

  Future<bool> consentWasAccepted(String dni) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'consentimientos',
      columns: ['id'],
      where: 'dni = ? AND version = ?',
      whereArgs: [dni, '1.0'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> saveConsent(String dni, Uint8List signaturePng) async {
    final db = await AppDatabase.instance.database;
    final acceptedAt = DateTime.now().toUtc().toIso8601String();
    await db.transaction((transaction) async {
      await transaction.insert('consentimientos', {
        'dni': dni,
        'version': '1.0',
        'accepted_at': acceptedAt,
        'signature_png': signaturePng,
        'sync_status': 0,
      });
      await SyncOutboxService().enqueueWith(
        transaction,
        entityType: 'CONSENT',
        entityId: '${dni}_1.0',
        operation: 'UPSERT',
        payload: {
          'dni': dni,
          'version': '1.0',
          'accepted_at': acceptedAt,
          'signature_source': 'consentimientos',
        },
      );
    });
  }

  Future<bool> trainingWasSigned(String trainingKey) async {
    final dni = await currentDni;
    if (dni == null) return false;
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'confirmaciones_capacitacion',
      columns: ['record_key'],
      where: 'dni = ? AND training_key = ?',
      whereArgs: [dni, trainingKey],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> saveTrainingSignature(
    String trainingKey,
    Uint8List signaturePng,
  ) async {
    final dni = await currentDni;
    if (dni == null) throw StateError('No existe una sesión activa.');
    final db = await AppDatabase.instance.database;
    final trainingRows = await db.query(
      'capacitaciones_importadas',
      columns: ['training_date'],
      where: 'training_key = ?',
      whereArgs: [trainingKey],
      limit: 1,
    );
    if (trainingRows.isEmpty) {
      throw StateError('La capacitación ya no se encuentra disponible.');
    }
    final control = await DocumentControlService().load(
      trainingKey,
      trainingRows.first['training_date'] as String? ?? '',
    );
    if (control.isClosed) {
      throw StateError('El registro ya fue cerrado por SSOMA.');
    }
    if (control.isExpired) {
      throw StateError('El plazo de 40 días para firmar ya venció.');
    }
    final confirmedAt = DateTime.now().toUtc().toIso8601String();
    final recordKey = '${dni}_$trainingKey';
    await db.transaction((transaction) async {
      await transaction.insert(
        'confirmaciones_capacitacion',
        {
          'record_key': recordKey,
          'dni': dni,
          'training_key': trainingKey,
          'confirmed_at': confirmedAt,
          'signature_png': signaturePng,
          'sync_status': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await transaction.update(
        'participantes_capacitacion',
        {'signature_status': 'FIRMADO'},
        where: 'training_key = ? AND dni = ?',
        whereArgs: [trainingKey, dni],
      );
      await SyncOutboxService().enqueueWith(
        transaction,
        entityType: 'CONFIRMATION',
        entityId: recordKey,
        operation: 'CREATE',
        payload: {
          'dni': dni,
          'training_id': trainingKey,
          'confirmed_at': confirmedAt,
          'signature_source': 'confirmaciones_capacitacion',
        },
      );
    });
  }

  Future<String?> _get(String key) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'app_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['setting_value'] as String;
  }

  Future<void> _set(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'app_settings',
      {'setting_key': key, 'setting_value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _delete(String key) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'app_settings',
      where: 'setting_key = ?',
      whereArgs: [key],
    );
  }
}
