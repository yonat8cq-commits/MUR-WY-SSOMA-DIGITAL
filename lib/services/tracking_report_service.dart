import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';

import 'admin_tracking_service.dart';

class TrackingReportService {
  final AdminTrackingService _tracking = AdminTrackingService();

  Future<String?> generateAndSave() async {
    final trainings = await _tracking.loadTrainings();
    final workbook = Excel.createExcel();
    final summary = workbook['Resumen'];
    final pending = workbook['Pendientes'];
    workbook.delete('Sheet1');

    _buildSummary(summary, trainings);
    await _buildPending(pending, trainings);

    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('No se pudo preparar el archivo Excel.');
    }
    final location = await getSaveLocation(
      suggestedName: 'Seguimiento_Firmas_MUR_WY.xlsx',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Libro Excel', extensions: ['xlsx']),
      ],
    );
    if (location == null) return null;
    final file = XFile.fromData(
      bytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      name: location.path.split('/').last,
    );
    await file.saveTo(location.path);
    return location.path;
  }

  void _buildSummary(Sheet sheet, List<TrainingProgress> trainings) {
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('I1'));
    final title = sheet.cell(CellIndex.indexByString('A1'));
    title.value = TextCellValue('MUR WY SSOMA DIGITAL - SEGUIMIENTO DE FIRMAS');
    title.cellStyle = _titleStyle();
    sheet.appendRow([
      TextCellValue('Generado'),
      TextCellValue(_dateTime(DateTime.now())),
    ]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Capacitación'),
      TextCellValue('Fecha'),
      TextCellValue('Estado'),
      TextCellValue('Participantes'),
      TextCellValue('Firmaron'),
      TextCellValue('Pendientes'),
      TextCellValue('Avance'),
      TextCellValue('Vencimiento'),
      TextCellValue('Versión'),
    ]);
    _styleHeader(sheet, 3, 9);

    for (final training in trainings) {
      sheet.appendRow([
        TextCellValue(training.course),
        TextCellValue(training.date),
        TextCellValue(training.status),
        IntCellValue(training.total),
        IntCellValue(training.signed),
        IntCellValue(training.pending),
        TextCellValue('${(training.ratio * 100).toStringAsFixed(1)}%'),
        TextCellValue(_date(training.deadline)),
        IntCellValue(training.version),
      ]);
    }
    _setWidths(sheet, [34, 14, 14, 14, 12, 12, 12, 15, 10]);
  }

  Future<void> _buildPending(
    Sheet sheet,
    List<TrainingProgress> trainings,
  ) async {
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('H1'));
    final title = sheet.cell(CellIndex.indexByString('A1'));
    title.value = TextCellValue('TRABAJADORES PENDIENTES DE FIRMA');
    title.cellStyle = _titleStyle();
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Capacitación'),
      TextCellValue('Fecha'),
      TextCellValue('Vencimiento'),
      TextCellValue('DNI'),
      TextCellValue('Apellidos y nombres'),
      TextCellValue('Empresa'),
      TextCellValue('Área'),
      TextCellValue('Cargo'),
    ]);
    _styleHeader(sheet, 2, 8);

    for (final training in trainings) {
      final participants = await _tracking.loadParticipants(training.key);
      for (final participant in participants.where((item) => !item.signed)) {
        sheet.appendRow([
          TextCellValue(training.course),
          TextCellValue(training.date),
          TextCellValue(_date(training.deadline)),
          TextCellValue(participant.dni),
          TextCellValue(participant.fullName),
          TextCellValue(participant.company),
          TextCellValue(participant.area),
          TextCellValue(participant.position),
        ]);
      }
    }
    _setWidths(sheet, [34, 14, 15, 13, 34, 18, 18, 24]);
  }

  CellStyle _titleStyle() => CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#1F4E78'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

  void _styleHeader(Sheet sheet, int rowIndex, int columns) {
    for (var column = 0; column < columns; column++) {
      sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: rowIndex),
      ).cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#404040'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );
    }
  }

  void _setWidths(Sheet sheet, List<double> widths) {
    for (var index = 0; index < widths.length; index++) {
      sheet.setColumnWidth(index, widths[index]);
    }
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _dateTime(DateTime value) =>
      '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
