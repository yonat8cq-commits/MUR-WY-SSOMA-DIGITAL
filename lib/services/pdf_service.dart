import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../database/app_database.dart';
import 'authorized_signature_service.dart';

class FsgiParticipant {
  final String dni;
  final String fullName;
  final String company;
  final String area;
  final String position;
  final Uint8List? signaturePng;

  const FsgiParticipant({
    required this.dni,
    required this.fullName,
    required this.company,
    required this.area,
    required this.position,
    required this.signaturePng,
  });
}

class FsgiRecord {
  final String course;
  final String date;
  final List<FsgiParticipant> participants;
  final AuthorizedSigner? trainer;
  final AuthorizedSigner? responsible;

  const FsgiRecord({
    required this.course,
    required this.date,
    required this.participants,
    required this.trainer,
    required this.responsible,
  });
}

class PdfService {
  static const _border = PdfColor.fromInt(0xFF222222);

  Future<FsgiRecord> loadRecord(String trainingKey) async {
    final db = await AppDatabase.instance.database;
    final trainingRows = await db.query(
      'capacitaciones_importadas',
      columns: ['course', 'training_date'],
      where: 'training_key = ?',
      whereArgs: [trainingKey],
      limit: 1,
    );
    if (trainingRows.isEmpty) {
      throw StateError('No se encontró la capacitación seleccionada.');
    }
    final rows = await db.rawQuery(
      '''
      SELECT p.dni, w.full_name, w.company, w.area, w.position,
             f.signature_png
      FROM participantes_capacitacion p
      INNER JOIN trabajadores_importados w ON w.dni = p.dni
      LEFT JOIN confirmaciones_capacitacion f
        ON f.training_key = p.training_key AND f.dni = p.dni
      WHERE p.training_key = ?
      ORDER BY w.full_name ASC
      ''',
      [trainingKey],
    );
    final signatureService = AuthorizedSignatureService();
    final trainerId = await signatureService.trainerIdFor(trainingKey);
    final trainer = await signatureService.loadSigner(trainerId);
    final responsible = await signatureService.loadSigner('jhonathan');
    return FsgiRecord(
      course: trainingRows.first['course'] as String? ?? '',
      date: trainingRows.first['training_date'] as String? ?? '',
      participants: rows
          .map(
            (row) => FsgiParticipant(
              dni: row['dni'] as String? ?? '',
              fullName: row['full_name'] as String? ?? '',
              company: row['company'] as String? ?? '',
              area: row['area'] as String? ?? '',
              position: row['position'] as String? ?? '',
              signaturePng: row['signature_png'] as Uint8List?,
            ),
          )
          .toList(),
      trainer: trainer,
      responsible: responsible,
    );
  }

  Future<Uint8List> generateFsgi(String trainingKey) async {
    final record = await loadRecord(trainingKey);
    final document = pw.Document();
    final totalPages = record.participants.isEmpty
        ? 1
        : (record.participants.length / 25).ceil();

    for (var pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final start = pageIndex * 25;
      final end = (start + 25 < record.participants.length)
          ? start + 25
          : record.participants.length;
      final pageParticipants = record.participants.sublist(start, end);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 18),
          build: (_) => _buildPage(
            record,
            pageParticipants,
            start,
            pageIndex + 1,
            totalPages,
          ),
        ),
      );
    }
    return document.save();
  }

  Future<String?> saveFsgi(String trainingKey) async {
    final record = await loadRecord(trainingKey);
    final bytes = await generateFsgi(trainingKey);
    final safeCourse = record.course
        .replaceAll(RegExp(r'[^A-Za-z0-9ÁÉÍÓÚÑáéíóúñ]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final location = await getSaveLocation(
      suggestedName:
          'F-SGI-04-01_${safeCourse.isEmpty ? 'capacitacion' : safeCourse}.pdf',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Documento PDF', extensions: ['pdf']),
      ],
    );
    if (location == null) return null;
    final file = XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: location.path.split('/').last,
    );
    await file.saveTo(location.path);
    return location.path;
  }

  pw.Widget _buildPage(
    FsgiRecord record,
    List<FsgiParticipant> participants,
    int start,
    int page,
    int totalPages,
  ) {
    final rows = List<FsgiParticipant?>.filled(25, null);
    for (var index = 0; index < participants.length; index++) {
      rows[index] = participants[index];
    }
    return pw.Column(
      children: [
        _box(
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'N° REGISTRO:',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                'Página $page de $totalPages',
                style: const pw.TextStyle(fontSize: 6),
              ),
            ],
          ),
          height: 20,
        ),
        _box(
          pw.Text(
            'DATOS DEL EMPLEADOR: MUR WY SAC',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          height: 18,
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _border, width: .45),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.3),
            1: pw.FlexColumnWidth(1.0),
            2: pw.FlexColumnWidth(3.0),
            3: pw.FlexColumnWidth(1.1),
            4: pw.FlexColumnWidth(1.2),
          },
          children: [
            _employerRow(
              [
                'RAZÓN O DENOMINACIÓN SOCIAL',
                'RUC',
                'DOMICILIO (Dirección, distrito, provincia, dpto.)',
                'ACTIVIDAD ECONÓMICA',
                'N° TRABAJADORES'
              ],
              header: true,
            ),
            _employerRow([
              'MUR WY SAC.',
              '20470407442',
              'AV. MALECÓN CHECA NRO. 3777 URB. CAMPOY - SAN JUAN DE LURIGANCHO - LIMA',
              'MINERÍA',
              record.participants.length.toString()
            ]),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _border, width: .45),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.5),
            1: pw.FlexColumnWidth(7.5)
          },
          children: [
            pw.TableRow(
              children: [
                _cell(
                  'CLASIFICACIÓN\n\nINDUCCIÓN      [ ]\nCAPACITACIÓN   [X]\nENTRENAMIENTO  [ ]\nSIMULACROS     [ ]\nOTROS          [ ]',
                  height: 77,
                  bold: true,
                  align: pw.Alignment.centerLeft,
                ),
                _trainingData(record),
              ],
            ),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _border, width: .4),
          columnWidths: const {
            0: pw.FlexColumnWidth(.48),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(3.1),
            3: pw.FlexColumnWidth(1.35),
            4: pw.FlexColumnWidth(1.1),
            5: pw.FlexColumnWidth(1.65),
            6: pw.FlexColumnWidth(1.55),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFE8E8E8),
              ),
              children: [
                'Nº',
                'DNI',
                'APELLIDOS Y NOMBRES',
                'EMPRESA',
                'ÁREA',
                'CARGO',
                'FIRMA'
              ].map((text) => _cell(text, height: 23, bold: true)).toList(),
            ),
            ...List.generate(25, (index) {
              final participant = rows[index];
              return pw.TableRow(
                children: [
                  _cell(
                    (start + index + 1).toString().padLeft(2, '0'),
                    height: 20,
                  ),
                  _cell(participant?.dni ?? '', height: 20),
                  _cell(
                    participant?.fullName ?? '',
                    height: 20,
                    align: pw.Alignment.centerLeft,
                  ),
                  _cell(participant?.company ?? '', height: 20),
                  _cell(participant?.area ?? '', height: 20),
                  _cell(participant?.position ?? '', height: 20),
                  _signatureCell(participant),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.TableRow _employerRow(List<String> values, {bool header = false}) =>
      pw.TableRow(
        decoration: header
            ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8E8E8))
            : null,
        children: values
            .map(
              (text) => _cell(
                text,
                height: header ? 28 : 34,
                bold: header,
              ),
            )
            .toList(),
      );

  pw.Widget _signatureCell(FsgiParticipant? participant) {
    if (participant == null) return _cell('', height: 20);
    if (participant.signaturePng == null) {
      return _cell('PENDIENTE', height: 20, color: PdfColors.grey700);
    }
    return pw.Container(
      height: 20,
      padding: const pw.EdgeInsets.all(1.5),
      alignment: pw.Alignment.center,
      child: pw.Image(
        pw.MemoryImage(participant.signaturePng!),
        fit: pw.BoxFit.contain,
      ),
    );
  }

  pw.Widget _trainingData(FsgiRecord record) {
    final trainer = record.trainer;
    return pw.Container(
      height: 77,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'TEMA: ${record.course}',
            style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
          ),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'EXPOSITOR: ${trainer?.fullName ?? 'NO ASIGNADO'}',
                  style: const pw.TextStyle(fontSize: 5.5),
                ),
              ),
              pw.SizedBox(
                width: 105,
                height: 27,
                child: trainer?.signaturePng == null
                    ? pw.Center(
                        child: pw.Text(
                          'FIRMA NO CARGADA',
                          style: const pw.TextStyle(
                            fontSize: 5,
                            color: PdfColors.grey700,
                          ),
                        ),
                      )
                    : pw.Image(
                        pw.MemoryImage(trainer!.signaturePng!),
                        fit: pw.BoxFit.contain,
                      ),
              ),
            ],
          ),
          pw.Text(
            'CARGO: ${trainer?.position ?? ''}        FECHA: ${record.date}',
            style: const pw.TextStyle(fontSize: 5.5),
          ),
          pw.Text(
            'EMPRESA: MUR WY S.A.C.        N° HORAS: __________',
            style: const pw.TextStyle(fontSize: 5.5),
          ),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'RESPONSABLE: ${record.responsible?.fullName ?? 'CUTIPA QUISPE JHONATHAN'} - ${record.responsible?.position ?? 'ASISTENTE SSOMA'}',
                  style: const pw.TextStyle(fontSize: 5),
                ),
              ),
              pw.SizedBox(
                width: 72,
                height: 14,
                child: record.responsible?.signaturePng == null
                    ? pw.Text(
                        'FIRMA NO CARGADA',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                          fontSize: 4.5,
                          color: PdfColors.grey700,
                        ),
                      )
                    : pw.Image(
                        pw.MemoryImage(record.responsible!.signaturePng!),
                        fit: pw.BoxFit.contain,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _box(pw.Widget child, {required double height}) => pw.Container(
        height: height,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        alignment: pw.Alignment.centerLeft,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border, width: .45),
        ),
        child: child,
      );

  pw.Widget _cell(
    String text, {
    required double height,
    bool bold = false,
    pw.Alignment align = pw.Alignment.center,
    PdfColor color = PdfColors.black,
  }) =>
      pw.Container(
        height: height,
        padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        alignment: align,
        child: pw.Text(
          text,
          textAlign: align == pw.Alignment.centerLeft
              ? pw.TextAlign.left
              : pw.TextAlign.center,
          maxLines: 3,
          style: pw.TextStyle(
            fontSize: 5.5,
            color: color,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
}
