import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'firebase_bootstrap_service.dart';

class FirebaseSyncResult {
  final int synced;
  final int failed;
  final int pending;

  const FirebaseSyncResult({
    required this.synced,
    required this.failed,
    required this.pending,
  });
}

class FirebaseSyncService {
  FirebaseSyncService._();

  static final instance = FirebaseSyncService._();
  bool _running = false;

  Future<FirebaseSyncResult> syncPending() async {
    if (_running ||
        !FirebaseBootstrapService.instance.isReady ||
        FirebaseAuth.instance.currentUser == null) {
      return FirebaseSyncResult(
        synced: 0,
        failed: 0,
        pending: await _pendingCount(),
      );
    }

    _running = true;
    var synced = 0;
    var failed = 0;
    final db = await AppDatabase.instance.database;
    try {
      final rows = await db.query(
        'sync_outbox',
        where: 'synced_at IS NULL',
        orderBy: 'created_at ASC',
        limit: 100,
      );
      for (final row in rows) {
        try {
          await _send(db, row);
          await db.update(
            'sync_outbox',
            {
              'synced_at': DateTime.now().toUtc().toIso8601String(),
              'last_error': null,
            },
            where: 'id = ?',
            whereArgs: [row['id']],
          );
          synced++;
        } catch (error) {
          await db.rawUpdate(
            'UPDATE sync_outbox SET attempts = attempts + 1, last_error = ? WHERE id = ?',
            [_safeError(error), row['id']],
          );
          failed++;
        }
      }
      if (synced > 0) {
        await db.insert(
          'sync_metadata',
          {
            'collection_name': 'firebase',
            'last_success_at': DateTime.now().toUtc().toIso8601String(),
            'last_error': failed == 0 ? null : '$failed operaciones pendientes',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } finally {
      _running = false;
    }
    return FirebaseSyncResult(
      synced: synced,
      failed: failed,
      pending: await _pendingCount(),
    );
  }

  Future<void> _send(Database db, Map<String, Object?> row) async {
    final type = row['entity_type'] as String;
    final id = row['entity_id'] as String;
    final payload = Map<String, Object?>.from(
      jsonDecode(row['payload_json'] as String) as Map,
    );
    payload['updated_at'] = FieldValue.serverTimestamp();

    if (type == 'CONSENT') {
      payload['signature_path'] = await _uploadConsent(db, id, payload);
    } else if (type == 'CONFIRMATION') {
      payload['signature_path'] = await _uploadConfirmation(db, id, payload);
    } else if (type == 'AUTHORIZED_SIGNATURE') {
      payload['signature_path'] = await _uploadAuthorizedSignature(db, id);
    }

    final target = _target(type, id, payload);
    await FirebaseFirestore.instance
        .collection(target.collection)
        .doc(target.id)
        .set(payload, SetOptions(merge: true));
  }

  _FirestoreTarget _target(
    String type,
    String id,
    Map<String, Object?> payload,
  ) {
    switch (type) {
      case 'WORKER':
        return _FirestoreTarget('users', id);
      case 'TRAINING':
      case 'TRAINING_COMPANY':
      case 'TRAINING_SIGNERS':
        return _FirestoreTarget('trainings', id);
      case 'TRAINING_PARTICIPANT':
        return _FirestoreTarget('training_participants', id);
      case 'CONSENT':
        return _FirestoreTarget('consents', id);
      case 'CONFIRMATION':
        return _FirestoreTarget('confirmations', id);
      case 'AUTHORIZED_SIGNATURE':
        return _FirestoreTarget('authorized_signatures', id);
      case 'DOCUMENT_CONTROL':
        return _FirestoreTarget('document_versions', id);
      case 'COMPANY':
        return _FirestoreTarget('companies', id);
      default:
        throw UnsupportedError('Tipo de sincronización no reconocido: $type');
    }
  }

  Future<String> _uploadConsent(
    Database db,
    String id,
    Map<String, Object?> payload,
  ) async {
    final dni = payload['dni'] as String;
    final rows = await db.query(
      'consentimientos',
      columns: ['signature_png'],
      where: 'dni = ? AND version = ?',
      whereArgs: [dni, payload['version']],
      limit: 1,
    );
    return _upload('consents/$dni/$id.png', _bytes(rows));
  }

  Future<String> _uploadConfirmation(
    Database db,
    String id,
    Map<String, Object?> payload,
  ) async {
    final dni = payload['dni'] as String;
    final rows = await db.query(
      'confirmaciones_capacitacion',
      columns: ['signature_png'],
      where: 'record_key = ?',
      whereArgs: [id],
      limit: 1,
    );
    return _upload('signatures/$dni/$id.png', _bytes(rows));
  }

  Future<String?> _uploadAuthorizedSignature(Database db, String id) async {
    final rows = await db.query(
      'firmas_autorizadas',
      columns: ['signature_png'],
      where: 'signer_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['signature_png'] == null) return null;
    return _upload('signatures/admin/$id.png', _bytes(rows));
  }

  Uint8List _bytes(List<Map<String, Object?>> rows) {
    if (rows.isEmpty || rows.first['signature_png'] == null) {
      throw StateError('No se encontró la firma local que debe sincronizarse.');
    }
    return rows.first['signature_png'] as Uint8List;
  }

  Future<String> _upload(String path, Uint8List bytes) async {
    final reference = FirebaseStorage.instance.ref(path);
    await reference.putData(
      bytes,
      SettableMetadata(contentType: 'image/png'),
    );
    return path;
  }

  Future<int> _pendingCount() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM sync_outbox WHERE synced_at IS NULL',
    );
    return rows.first['total'] as int? ?? 0;
  }

  String _safeError(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 400 ? text : text.substring(0, 400);
  }
}

class _FirestoreTarget {
  final String collection;
  final String id;

  const _FirestoreTarget(this.collection, this.id);
}
