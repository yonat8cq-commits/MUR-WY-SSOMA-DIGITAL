class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();

  DatabaseService._internal();

  factory DatabaseService() => instance;

  Future<void> initialize() async {
    // Inicialización futura de SQLite local.
  }
}
