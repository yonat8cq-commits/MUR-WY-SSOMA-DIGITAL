class StorageService {
  final Map<String, dynamic> _storage = {};

  Future<void> save(String key, dynamic value) async {
    _storage[key] = value;
  }

  Future<dynamic> get(String key) async {
    return _storage[key];
  }

  Future<void> remove(String key) async {
    _storage.remove(key);
  }
}
