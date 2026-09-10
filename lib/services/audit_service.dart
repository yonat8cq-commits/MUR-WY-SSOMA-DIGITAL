import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';

import '../database/app_database.dart';

class AuditEntry {
  final int id;
  final DateTime occurredAt;
  final String actor;
  final String category;
  final String action;
  final String detail;
  final String targetType;
  final String targetId;

  const AuditEntry({
    required this.id,
    required this.occurredAt,
    required this.actor,
    required this.category,
    required this.action,
    required this.detail,
    required this.targetType,
    required this.targetId,
  });
}

class AuditService {
  static const admin = 'CUTIPA QUISPE JHONATHAN';

  Future<void> record({
    required String category,
    required String action,
    required String detail,
    String actor = admin,
    String? targetType,
    String? targetId,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.insert('auditoria', {
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'actor': actor,
      'category': category,
      'action': action,
      'detail': detail,
      'target_type': targetType,
      'target_id': targetId,
    });
  }

  Future<List<AuditEntry>> load({String? category, String? query}) async {
    final db = await AppDatabase.instance.database;
    final where = <String>[];
    final args = <Object>[];
    if (category != null && category != 'TODAS') {
      where.add('category = ?');
      args.add(category);
    }
    final normalized = query?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      where.add('(action LIKE ? OR detail LIKE ? OR target_id LIKE ?)');
      final value = '%$normalized%';
      args.addAll([value, value, value]);
    }
    final rows = await db.query(
      'auditoria',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'occurred_at DESC',
      limit: 1000,
    );
    return rows.map((row) => AuditEntry(
      id: row['id'] as int,
      occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
      actor: row['actor'] as String,
      category: row['category'] as String,
      action: row['action'] as String,
      detail: row['detail'] as String,
      targetType: row['target_type'] as String? ?? '',
      targetId: row['target_id'] as String? ?? '',
    )).toList();
  }

  Future<String?> exportExcel(List<AuditEntry> entries) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Auditoría'];
    workbook.delete('Sheet1');
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('G1'));
    sheet.cell(CellIndex.indexByString('A1')).value =
        TextCellValue('MUR WY SSOMA DIGITAL - REGISTRO DE AUDITORÍA');
    sheet.appendRow([TextCellValue('Generado'), TextCellValue(_dateTime(DateTime.now()))]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Fecha y hora'), TextCellValue('Responsable'),
      TextCellValue('Categoría'), TextCellValue('Acción'),
      TextCellValue('Detalle'), TextCellValue('Tipo de registro'),
      TextCellValue('Identificador'),
    ]);
    for (final entry in entries) {
      sheet.appendRow([
        TextCellValue(_dateTime(entry.occurredAt)), TextCellValue(entry.actor),
        TextCellValue(entry.category), TextCellValue(entry.action),
        TextCellValue(entry.detail), TextCellValue(entry.targetType),
        TextCellValue(entry.targetId),
      ]);
    }
    const widths = [20.0, 30.0, 18.0, 24.0, 55.0, 20.0, 30.0];
    for (var i = 0; i < widths.length; i++) sheet.setColumnWidth(i, widths[i]);
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('No se pudo generar el reporte.');
    final location = await getSaveLocation(
      suggestedName: 'Auditoria_MUR_WY_SSOMA.xlsx',
      acceptedTypeGroups: const [XTypeGroup(label: 'Libro Excel', extensions: ['xlsx'])],
    );
    if (location == null) return null;
    await XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      name: location.path.split('/').last,
    ).saveTo(location.path);
    return location.path;
  }

  String _dateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
