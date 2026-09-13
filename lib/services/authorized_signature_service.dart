import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'sync_outbox_service.dart';
import 'signature_image_service.dart';

class AuthorizedSigner {
  final String id;
  final String fullName;
  final String position;
  final String role;
  final Uint8List? signaturePng;
  final bool active;

  const AuthorizedSigner({
    required this.id,
    required this.fullName,
    required this.position,
    required this.role,
    required this.signaturePng,
    required this.active,
  });
}

class AuthorizedSignatureService {
  Future<List<AuthorizedSigner>> loadSigners() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'firmas_autorizadas',
      orderBy: "CASE signer_role WHEN 'RESPONSABLE' THEN 0 ELSE 1 END, full_name",
    );
    final result = <AuthorizedSigner>[];
    for (final row in rows) {
      final signer = _fromRow(row);
      final signature = signer.signaturePng == null
          ? await _bundledSignature(signer.id)
          : SignatureImageService.normalize(
              signer.signaturePng!,
              blackInk: signer.id == 'karina',
            );
      result.add(AuthorizedSigner(
        id: signer.id,
        fullName: signer.fullName,
        position: signer.position,
        role: signer.role,
        signaturePng: signature,
        active: signer.active,
      ));
    }
    return result;
  }

  Future<List<AuthorizedSigner>> loadTrainers() async {
    final signers = await loadSigners();
    return signers
        .where((signer) => signer.role == 'CAPACITADOR' && signer.active)
        .toList();
  }

  Future<List<AuthorizedSigner>> loadResponsibles() async {
    final signers = await loadSigners();
    return signers.where((signer) => signer.active).toList();
  }

  Future<AuthorizedSigner?> loadSigner(String? id) async {
    if (id == null || id.isEmpty) return null;
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'firmas_autorizadas',
      where: 'signer_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final signer = _fromRow(rows.first);
    if (signer.signaturePng != null) {
      return AuthorizedSigner(
        id: signer.id,
        fullName: signer.fullName,
        position: signer.position,
        role: signer.role,
        signaturePng: SignatureImageService.normalize(
          signer.signaturePng!,
          blackInk: signer.id == 'karina',
        ),
        active: signer.active,
      );
    }
    final bundled = await _bundledSignature(id);
    return AuthorizedSigner(
      id: signer.id,
      fullName: signer.fullName,
      position: signer.position,
      role: signer.role,
      signaturePng: bundled,
      active: signer.active,
    );
  }

  Future<void> saveSignature(String id, Uint8List signaturePng) async {
    final db = await AppDatabase.instance.database;
    final normalizedSignature = SignatureImageService.normalize(
      signaturePng,
      blackInk: id == 'karina',
    );
    await db.update(
      'firmas_autorizadas',
      {
        'signature_png': normalizedSignature,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'signer_id = ?',
      whereArgs: [id],
    );
    await SyncOutboxService().enqueue(
      entityType: 'AUTHORIZED_SIGNATURE',
      entityId: id,
      operation: 'UPSERT',
      payload: {'signer_id': id, 'signature_source': 'firmas_autorizadas'},
    );
  }

  Future<String?> trainerIdFor(String trainingKey) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'firmantes_capacitacion',
      columns: ['trainer_id'],
      where: 'training_key = ?',
      whereArgs: [trainingKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['trainer_id'] as String?;
  }

  Future<String> responsibleIdFor(String trainingKey) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'firmantes_capacitacion',
      columns: ['responsible_id'],
      where: 'training_key = ?',
      whereArgs: [trainingKey],
      limit: 1,
    );
    return rows.isEmpty
        ? 'jhonathan'
        : rows.first['responsible_id'] as String? ?? 'jhonathan';
  }

  Future<void> assignTrainer(String trainingKey, String trainerId) async {
    await _assign(trainingKey, trainerId: trainerId);
  }

  Future<void> assignResponsible(
    String trainingKey,
    String responsibleId,
  ) async {
    await _assign(trainingKey, responsibleId: responsibleId);
  }

  Future<void> _assign(
    String trainingKey, {
    String? trainerId,
    String? responsibleId,
  }) async {
    final db = await AppDatabase.instance.database;
    final current = await db.query(
      'firmantes_capacitacion',
      where: 'training_key = ?',
      whereArgs: [trainingKey],
      limit: 1,
    );
    final selectedTrainer = trainerId ??
        (current.isEmpty ? null : current.first['trainer_id'] as String?);
    final selectedResponsible = responsibleId ??
        (current.isEmpty
            ? 'jhonathan'
            : current.first['responsible_id'] as String? ?? 'jhonathan');
    await db.insert(
      'firmantes_capacitacion',
      {
        'training_key': trainingKey,
        'trainer_id': selectedTrainer,
        'responsible_id': selectedResponsible,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await SyncOutboxService().enqueue(
      entityType: 'TRAINING_SIGNERS',
      entityId: trainingKey,
      operation: 'UPSERT',
      payload: {
        'training_id': trainingKey,
        'trainer_id': selectedTrainer,
        'responsible_id': selectedResponsible,
      },
    );
  }

  AuthorizedSigner _fromRow(Map<String, Object?> row) => AuthorizedSigner(
        id: row['signer_id'] as String,
        fullName: row['full_name'] as String? ?? '',
        position: row['position'] as String? ?? '',
        role: row['signer_role'] as String? ?? '',
        signaturePng: row['signature_png'] as Uint8List?,
        active: (row['active'] as int? ?? 1) == 1,
      );

  Future<Uint8List?> _bundledSignature(String id) async {
    const assets = {
      'roly': 'assets/signatures/roly_quispe_turpo.png',
      'karina': 'assets/signatures/karina_castillo_cordova.png',
      'jhonathan': 'assets/signatures/jhonathan_cutipa_quispe.png',
    };
    final path = assets[id];
    if (path == null) return null;
    try {
      final data = await rootBundle.load(path);
      return SignatureImageService.normalize(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        blackInk: id == 'karina',
      );
    } catch (_) {
      return null;
    }
  }
}
