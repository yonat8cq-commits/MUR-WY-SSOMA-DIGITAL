import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'firebase_bootstrap_service.dart';

class FirebasePullResult {
  final int trainings;
  final int confirmations;

  const FirebasePullResult({
    required this.trainings,
    required this.confirmations,
  });
}

class FirebasePullService {
  FirebasePullService._();

  static final instance = FirebasePullService._();

  Future<FirebasePullResult> pullWorkerWorkspace(String dni) async {
    if (!FirebaseBootstrapService.instance.isReady ||
        FirebaseAuth.instance.currentUser == null) {
      return const FirebasePullResult(trainings: 0, confirmations: 0);
    }

    final firestore = FirebaseFirestore.instance;
    final user = await firestore.collection('users').doc(dni).get();
    if (!user.exists || user.data() == null) {
      throw StateError('El DNI todavía no fue publicado desde el panel central.');
    }
    final assignments = await firestore
        .collection('training_participants')
        .where('dni', isEqualTo: dni)
        .get();
    final trainingIds = assignments.docs
        .map((doc) => _text(doc.data()['training_id']))
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final trainingDocs = await Future.wait(
      trainingIds.map((id) => firestore.collection('trainings').doc(id).get()),
    );
    final confirmations = await firestore
        .collection('confirmations')
        .where('dni', isEqualTo: dni)
        .get();

    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((transaction) async {
      final profile = user.data()!;
      final remoteRequiresPasswordChange = profile['requires_password_change'];
      final updateProfile = <String, Object?>{
        'full_name': _text(profile['full_name']),
        'company': _text(profile['company']),
        'area': _text(profile['roster_area']).isNotEmpty
            ? _text(profile['roster_area'])
            : _text(profile['area']),
        'position': _text(profile['roster_position']).isNotEmpty
            ? _text(profile['roster_position'])
            : _text(profile['position']),
        'account_status': _text(profile['account_status']).isEmpty
            ? 'TEMPORAL'
            : _text(profile['account_status']),
        'updated_at': now,
      };
      if (remoteRequiresPasswordChange is bool) {
        updateProfile['requires_password_change'] =
            remoteRequiresPasswordChange ? 1 : 0;
      }
      await transaction.insert(
        'trabajadores_importados',
        {
          'dni': dni,
          ...updateProfile,
          'requires_password_change':
              remoteRequiresPasswordChange == false ? 0 : 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await transaction.update(
        'trabajadores_importados',
        updateProfile,
        where: 'dni = ?',
        whereArgs: [dni],
      );

      for (final document in trainingDocs) {
        final data = document.data();
        if (!document.exists || data == null) continue;
        final status = _text(data['status']).isEmpty
            ? 'BORRADOR'
            : _text(data['status']);
        await transaction.insert(
          'capacitaciones_importadas',
          {
            'training_key': document.id,
            'course': _text(data['course']),
            'training_date': _text(data['training_date']),
            'hours': _numberText(data['hours']),
            'approved_participants': _integer(data['approved_participants']),
            'status': status,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await transaction.insert(
          'participantes_capacitacion',
          {
            'training_key': document.id,
            'dni': dni,
            'signature_status': 'PENDIENTE',
            'assigned_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      for (final document in confirmations.docs) {
        final data = document.data();
        final trainingId = _text(data['training_id']);
        final signature = _bytes(data['signature_blob']);
        if (trainingId.isEmpty || signature == null) continue;
        await transaction.insert(
          'confirmaciones_capacitacion',
          {
            'record_key': document.id,
            'dni': dni,
            'training_key': trainingId,
            'confirmed_at': _dateText(data['confirmed_at']),
            'signature_png': signature,
            'sync_status': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await transaction.update(
          'participantes_capacitacion',
          {'signature_status': 'FIRMADO'},
          where: 'training_key = ? AND dni = ?',
          whereArgs: [trainingId, dni],
        );
      }
      await transaction.insert(
        'sync_metadata',
        {
          'collection_name': 'worker_pull_$dni',
          'last_pulled_at': now,
          'last_success_at': now,
          'last_error': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    return FirebasePullResult(
      trainings: trainingDocs.where((doc) => doc.exists).length,
      confirmations: confirmations.docs.length,
    );
  }

  String _text(Object? value) => value?.toString().trim() ?? '';

  String _numberText(Object? value) {
    if (value is num && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return _text(value).replaceAll(RegExp(r'\.0$'), '');
  }

  int _integer(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(_text(value)) ?? 0;
  }

  String _dateText(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    final text = _text(value);
    return text.isEmpty ? DateTime.now().toUtc().toIso8601String() : text;
  }

  Uint8List? _bytes(Object? value) {
    if (value is Blob) return value.bytes;
    if (value is Uint8List) return value;
    return null;
  }
}
