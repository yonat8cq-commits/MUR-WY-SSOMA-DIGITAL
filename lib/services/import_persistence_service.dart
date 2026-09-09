import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'excel_service.dart';

class ImportSaveSummary {
  final int workers;
  final int trainings;
  final int assignments;

  const ImportSaveSummary({
    required this.workers,
    required this.trainings,
    required this.assignments,
  });
}

class ImportPersistenceService {
  Future<ImportSaveSummary> save(
    TecsupImportResult result,
    String fileName,
  ) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final workerIds = <String>{};
    var assignments = 0;

    await db.transaction((transaction) async {
      await transaction.insert('importaciones_tecsup', {
        'file_name': fileName,
        'imported_at': now,
        'total_rows': result.totalRows,
        'approved_rows': result.approvedRows,
        'excluded_rows': result.excludedRows,
      });

      for (final training in result.trainings) {
        await transaction.insert(
          'capacitaciones_importadas',
          {
            'training_key': training.key,
            'course': training.course,
            'training_date': training.date,
            'approved_participants': training.approvedParticipants,
            'status': 'BORRADOR',
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await transaction.update(
          'capacitaciones_importadas',
          {
            'course': training.course,
            'training_date': training.date,
            'approved_participants': training.approvedParticipants,
            'updated_at': now,
          },
          where: 'training_key = ?',
          whereArgs: [training.key],
        );
      }

      for (final participant in result.participants) {
        workerIds.add(participant.dni);
        await transaction.insert(
          'trabajadores_importados',
          {
            'dni': participant.dni,
            'full_name': participant.fullName,
            'company': participant.company,
            'area': participant.area,
            'position': participant.position,
            'account_status': 'TEMPORAL',
            'requires_password_change': 1,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await transaction.update(
          'trabajadores_importados',
          {
            'full_name': participant.fullName,
            'company': participant.company,
            'area': participant.area,
            'position': participant.position,
            'updated_at': now,
          },
          where: 'dni = ?',
          whereArgs: [participant.dni],
        );
        final inserted = await transaction.insert(
          'participantes_capacitacion',
          {
            'training_key': participant.trainingKey,
            'dni': participant.dni,
            'signature_status': 'PENDIENTE',
            'assigned_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (inserted > 0) assignments++;
      }
    });

    return ImportSaveSummary(
      workers: workerIds.length,
      trainings: result.trainings.length,
      assignments: assignments,
    );
  }
}
