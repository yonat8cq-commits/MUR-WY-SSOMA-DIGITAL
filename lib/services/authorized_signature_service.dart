import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

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
    return rows.map(_fromRow).toList();
  }

  Future<List<AuthorizedSigner>> loadTrainers() async {
    final signers = await loadSigners();
    return signers
        .where((signer) => signer.role == 'CAPACITADOR' && signer.active)
        .toList();
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
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<void> saveSignature(String id, Uint8List signaturePng) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'firmas_autorizadas',
      {
        'signature_png': signaturePng,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'signer_id = ?',
      whereArgs: [id],
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

  Future<void> assignTrainer(String trainingKey, String trainerId) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'firmantes_capacitacion',
      {
        'training_key': trainingKey,
        'trainer_id': trainerId,
        'responsible_id': 'jhonathan',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
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
}
