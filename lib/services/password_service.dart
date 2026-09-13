import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../database/app_database.dart';

class PasswordService {
  Future<void> setPassword(String dni, String password) async {
    final salt = CredentialHasher.generateSalt();
    final hash = CredentialHasher.hash(password, salt);
    final db = await AppDatabase.instance.database;
    await db.update(
      'trabajadores_importados',
      {
        'password_hash': hash,
        'password_salt': salt,
        'requires_password_change': 0,
        'account_status': 'ACTIVO',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'dni = ?',
      whereArgs: [dni],
    );
  }

  Future<bool> verify(String dni, String password) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'trabajadores_importados',
      columns: ['password_hash', 'password_salt'],
      where: 'dni = ?',
      whereArgs: [dni],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final expected = rows.first['password_hash'] as String?;
    final salt = rows.first['password_salt'] as String?;
    if (expected == null || salt == null) return false;
    return CredentialHasher.equals(
      expected,
      CredentialHasher.hash(password, salt),
    );
  }
}

class CredentialHasher {
  static String generateSalt() {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(24, (_) => random.nextInt(256)),
    );
  }

  static String hash(String password, String salt) {
    List<int> value = utf8.encode('$salt:$password');
    for (var round = 0; round < 20000; round++) {
      value = sha256.convert(value).bytes;
    }
    return base64UrlEncode(value);
  }

  static bool equals(String expected, String actual) {
    if (expected.length != actual.length) return false;
    var difference = 0;
    for (var index = 0; index < expected.length; index++) {
      difference |= expected.codeUnitAt(index) ^ actual.codeUnitAt(index);
    }
    return difference == 0;
  }
}
