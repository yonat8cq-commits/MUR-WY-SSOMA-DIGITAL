import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'password_service.dart';
import 'audit_service.dart';

class AdminAuthService {
  static bool _sessionAuthorized = false;

  bool get sessionAuthorized => _sessionAuthorized;

  Future<bool> get isConfigured async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'app_settings',
      columns: ['setting_key'],
      where: 'setting_key = ?',
      whereArgs: ['admin_password_hash'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<String> configure(String password) async {
    final salt = CredentialHasher.generateSalt();
    final hash = CredentialHasher.hash(password, salt);
    final recoveryCode = _generateRecoveryCode();
    final recoverySalt = CredentialHasher.generateSalt();
    final recoveryHash = CredentialHasher.hash(
      _normalizeRecoveryCode(recoveryCode),
      recoverySalt,
    );
    final db = await AppDatabase.instance.database;
    await db.transaction((transaction) async {
      await _set(transaction, 'admin_password_salt', salt);
      await _set(transaction, 'admin_password_hash', hash);
      await _set(transaction, 'admin_recovery_salt', recoverySalt);
      await _set(transaction, 'admin_recovery_hash', recoveryHash);
      await _set(
        transaction,
        'admin_password_updated_at',
        DateTime.now().toUtc().toIso8601String(),
      );
    });
    _sessionAuthorized = true;
    await AuditService().record(
      category: 'SEGURIDAD',
      action: 'CREDENCIALES DE ADMINISTRADOR CONFIGURADAS',
      detail: 'Se configuró la contraseña y se emitió un código de recuperación.',
    );
    return recoveryCode;
  }

  Future<bool> login(String password) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'app_settings',
      where: 'setting_key IN (?, ?)',
      whereArgs: ['admin_password_hash', 'admin_password_salt'],
    );
    final values = <String, String>{
      for (final row in rows)
        row['setting_key'] as String: row['setting_value'] as String,
    };
    final expected = values['admin_password_hash'];
    final salt = values['admin_password_salt'];
    if (expected == null || salt == null) return false;
    final valid = CredentialHasher.equals(
      expected,
      CredentialHasher.hash(password, salt),
    );
    _sessionAuthorized = valid;
    await AuditService().record(
      category: 'SEGURIDAD',
      action: valid ? 'INICIO DE SESIÓN EXITOSO' : 'INTENTO DE ACCESO RECHAZADO',
      detail: valid
          ? 'El super administrador ingresó al panel.'
          : 'Se rechazó un intento por contraseña incorrecta.',
      actor: valid ? AuditService.admin : 'USUARIO NO AUTENTICADO',
    );
    return valid;
  }

  void logout() => _sessionAuthorized = false;

  Future<String?> ensureRecoveryCode() async {
    final values = await _loadSettings([
      'admin_recovery_hash',
      'admin_recovery_salt',
    ]);
    if (values.length == 2) return null;
    final recoveryCode = _generateRecoveryCode();
    final salt = CredentialHasher.generateSalt();
    final hash = CredentialHasher.hash(
      _normalizeRecoveryCode(recoveryCode),
      salt,
    );
    final db = await AppDatabase.instance.database;
    await db.transaction((transaction) async {
      await _set(transaction, 'admin_recovery_salt', salt);
      await _set(transaction, 'admin_recovery_hash', hash);
    });
    return recoveryCode;
  }

  Future<String?> resetWithRecoveryCode(
    String recoveryCode,
    String newPassword,
  ) async {
    final values = await _loadSettings([
      'admin_recovery_hash',
      'admin_recovery_salt',
    ]);
    final expected = values['admin_recovery_hash'];
    final salt = values['admin_recovery_salt'];
    if (expected == null || salt == null) return null;
    final valid = CredentialHasher.equals(
      expected,
      CredentialHasher.hash(_normalizeRecoveryCode(recoveryCode), salt),
    );
    if (!valid) return null;
    return configure(newPassword);
  }

  Future<Map<String, String>> _loadSettings(List<String> keys) async {
    final db = await AppDatabase.instance.database;
    final placeholders = List.filled(keys.length, '?').join(', ');
    final rows = await db.query(
      'app_settings',
      where: 'setting_key IN ($placeholders)',
      whereArgs: keys,
    );
    return {
      for (final row in rows)
        row['setting_key'] as String: row['setting_value'] as String,
    };
  }

  String _generateRecoveryCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final raw = List.generate(
      16,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return '${raw.substring(0, 4)}-${raw.substring(4, 8)}-'
        '${raw.substring(8, 12)}-${raw.substring(12, 16)}';
  }

  String _normalizeRecoveryCode(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Future<void> _set(
    DatabaseExecutor db,
    String key,
    String value,
  ) =>
      db.insert(
        'app_settings',
        {'setting_key': key, 'setting_value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
