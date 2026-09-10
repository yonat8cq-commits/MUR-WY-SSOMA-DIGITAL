import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class SyncOutboxService {
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final db = await AppDatabase.instance.database;
    await enqueueWith(db,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload);
  }

  Future<void> enqueueWith(
    DatabaseExecutor db, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) => db.insert(
        'sync_outbox',
        {
          'entity_type': entityType,
          'entity_id': entityId,
          'operation': operation,
          'payload_json': jsonEncode(payload),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'attempts': 0,
          'last_error': null,
          'synced_at': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
