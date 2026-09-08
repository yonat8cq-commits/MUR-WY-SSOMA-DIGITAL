import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

class OfflineWorkflowService {
  static final OfflineWorkflowService instance = OfflineWorkflowService._();
  OfflineWorkflowService._();

  Future<void> openSession(String dni) => _set('current_dni', dni);

  Future<String?> get currentDni => _get('current_dni');

  Future<bool> passwordWasChanged(String dni) async =>
      await _get('password_changed_$dni') == 'true';

  Future<void> markPasswordChanged(String dni) =>
      _set('password_changed_$dni', 'true');

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
    await db.insert('consentimientos', {
      'dni': dni,
      'version': '1.0',
      'accepted_at': DateTime.now().toUtc().toIso8601String(),
      'signature_png': signaturePng,
      'sync_status': 0,
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
    final confirmedAt = DateTime.now().toUtc().toIso8601String();
    final db = await AppDatabase.instance.database;
    await db.insert(
      'confirmaciones_capacitacion',
      {
        'record_key': dni + '_' + trainingKey,
        'dni': dni,
        'training_key': trainingKey,
        'confirmed_at': confirmedAt,
        'signature_png': signaturePng,
        'sync_status': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
}
