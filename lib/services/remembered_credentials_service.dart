import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RememberedCredentials {
  final String dni;
  final String password;

  const RememberedCredentials({required this.dni, required this.password});
}

class RememberedCredentialsService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _dniKey = 'remembered_worker_dni';
  static const _passwordKey = 'remembered_worker_password';

  Future<RememberedCredentials?> load() async {
    final dni = await _storage.read(key: _dniKey);
    final password = await _storage.read(key: _passwordKey);
    if (dni == null || password == null || dni.isEmpty || password.isEmpty) {
      return null;
    }
    return RememberedCredentials(dni: dni, password: password);
  }

  Future<void> save(String dni, String password) async {
    await _storage.write(key: _dniKey, value: dni);
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<void> updatePassword(String dni, String password) async {
    final rememberedDni = await _storage.read(key: _dniKey);
    if (rememberedDni == dni) {
      await _storage.write(key: _passwordKey, value: password);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _dniKey);
    await _storage.delete(key: _passwordKey);
  }
}
