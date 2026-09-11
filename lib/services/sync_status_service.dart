import '../database/app_database.dart';

class SyncStatus {
  final int pending;
  final int errors;
  final DateTime? lastSuccess;

  const SyncStatus({required this.pending, required this.errors, this.lastSuccess});
}

class SyncStatusService {
  Future<SyncStatus> load() async {
    final db = await AppDatabase.instance.database;
    final pending = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM sync_outbox WHERE synced_at IS NULL',
    );
    final errors = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM sync_outbox WHERE synced_at IS NULL AND last_error IS NOT NULL",
    );
    final success = await db.rawQuery(
      'SELECT MAX(last_success_at) AS value FROM sync_metadata',
    );
    final value = success.first['value'] as String?;
    return SyncStatus(
      pending: pending.first['total'] as int? ?? 0,
      errors: errors.first['total'] as int? ?? 0,
      lastSuccess: value == null ? null : DateTime.tryParse(value)?.toLocal(),
    );
  }
}
