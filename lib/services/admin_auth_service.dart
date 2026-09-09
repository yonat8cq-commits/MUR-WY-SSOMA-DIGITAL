import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'password_service.dart';

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

  Future<void> configure(String password) async {
    final salt = CredentialHasher.generateSalt();
    final hash = CredentialHasher.hash(password, salt);
    final db = await AppDatabase.instance.database;
    await db.transaction((transaction) async {
      await _set(transaction, 'admin_password_salt', salt);
      await _set(transaction, 'admin_password_hash', hash);
      await _set(
        transaction,
        'admin_password_updated_at',
        DateTime.now().toUtc().toIso8601String(),
      );
    });
    _sessionAuthorized = true;
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
    return valid;
  }

  void logout() => _sessionAuthorized = false;

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
