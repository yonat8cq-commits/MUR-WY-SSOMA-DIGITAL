import 'dart:typed_data';
import 'package:excel/excel.dart';

class TecsupImportResult {
  final int totalRows;
  final int approvedRows;
  final int excludedRows;
  final int uniqueWorkers;
  final List<ImportedTraining> trainings;
  final List<String> warnings;

  const TecsupImportResult({
    required this.totalRows,
    required this.approvedRows,
    required this.excludedRows,
    required this.uniqueWorkers,
    required this.trainings,
    required this.warnings,
  });

  factory TecsupImportResult.referencePreview() => const TecsupImportResult(
        totalRows: 942,
        approvedRows: 761,
        excludedRows: 181,
        uniqueWorkers: 93,
        trainings: [
          ImportedTraining(
            key: '194076|1|01/02/2026',
            course:
                'HIGIENE OCUPACIONAL (AGENTES FÍSICOS, QUÍMICOS, BIOLÓGICOS)',
            date: '01/02/2026',
            approvedParticipants: 5,
          ),
          ImportedTraining(
            key: 'RESUMEN',
            course: 'Capacitaciones independientes detectadas',
            date: 'Archivo completo',
            approvedParticipants: 230,
          ),
        ],
        warnings: [
          'DNI 41704699 aparece duplicado en el padrón de personal.',
          '7 aprobados no están en el padrón y crearán una cuenta nueva.',
        ],
      );
}

class ImportedTraining {
  final String key;
  final String course;
  final String date;
  final int approvedParticipants;

  const ImportedTraining({
    required this.key,
    required this.course,
    required this.date,
    required this.approvedParticipants,
  });
}

class ExcelService {
  static const _requiredHeaders = {
    'DNI',
    'NOMBRE COMPLETO',
    'CURSO',
    'FECHA DE CURSO',
    'ESTADO',
    'ID PROGRAMACION',
    'GRUPO',
  };

  TecsupImportResult importTecsup(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook.tables['lista'];
    if (sheet == null || sheet.rows.isEmpty) {
      throw const FormatException(
        'El archivo no contiene la hoja obligatoria "lista".',
      );
    }

    final headers = <String, int>{};
    for (var column = 0; column < sheet.rows.first.length; column++) {
      final value = _text(sheet.rows.first[column]?.value);
      if (value.isNotEmpty) headers[_normalize(value)] = column;
    }

    final missing =
        _requiredHeaders.where((header) => !headers.containsKey(header)).toList();
    if (missing.isNotEmpty) {
      throw FormatException(
        'Faltan columnas obligatorias: ' + missing.join(', ') + '.',
      );
    }

    var total = 0;
    var approved = 0;
    final workers = <String>{};
    final grouped = <String, _TrainingAccumulator>{};
    final warnings = <String>[];

    for (final row in sheet.rows.skip(1)) {
      final dni = _read(row, headers, 'DNI').replaceAll(RegExp(r'\.0$'), '');
      final course = _read(row, headers, 'CURSO');
      if (dni.isEmpty && course.isEmpty) continue;
      total++;

      final status = _normalize(_read(row, headers, 'ESTADO'));
      if (status != 'APROBADO') continue;
      approved++;
      workers.add(dni.padLeft(8, '0'));

      final date = _read(row, headers, 'FECHA DE CURSO');
      final programId = _read(row, headers, 'ID PROGRAMACION');
      final group = _read(row, headers, 'GRUPO');
      final key = [programId, group, course, date].join('|');
      grouped.putIfAbsent(
        key,
        () => _TrainingAccumulator(key: key, course: course, date: date),
      );
      grouped[key]!.participants.add(dni);
    }

    if (total == 0) warnings.add('El archivo no contiene registros de personal.');
    if (approved == 0) {
      warnings.add('No se encontraron filas con el estado exacto APROBADO.');
    }

    final trainings = grouped.values
        .map(
          (item) => ImportedTraining(
            key: item.key,
            course: item.course,
            date: item.date,
            approvedParticipants: item.participants.length,
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return TecsupImportResult(
      totalRows: total,
      approvedRows: approved,
      excludedRows: total - approved,
      uniqueWorkers: workers.length,
      trainings: trainings,
      warnings: warnings,
    );
  }

  String _read(
    List<Data?> row,
    Map<String, int> headers,
    String header,
  ) {
    final index = headers[header]!;
    return index < row.length ? _text(row[index]?.value) : '';
  }

  String _text(CellValue? value) => value?.toString().trim() ?? '';

  String _normalize(String value) => value.trim().toUpperCase();
}

class _TrainingAccumulator {
  final String key;
  final String course;
  final String date;
  final Set<String> participants = {};

  _TrainingAccumulator({
    required this.key,
    required this.course,
    required this.date,
  });
}
