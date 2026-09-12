import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../database/app_database.dart';
import 'authorized_signature_service.dart';
import 'company_service.dart';
import 'signature_image_service.dart';

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
  final String hours;
  final List<FsgiParticipant> participants;
  final AuthorizedSigner? trainer;
  final AuthorizedSigner? responsible;
  final CompanyProfile company;

  const FsgiRecord({
    required this.course,
    required this.date,
    required this.hours,
    required this.participants,
    required this.trainer,
    required this.responsible,
    required this.company,
  });
}

class PdfService {
  Future<FsgiRecord> loadRecord(
    String trainingKey, {
    bool signedOnly = false,
  }) async {
    final db = await AppDatabase.instance.database;
    final trainingRows = await db.query(
      'capacitaciones_importadas',
      columns: ['course', 'training_date', 'hours'],
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
        ${signedOnly ? 'AND f.record_key IS NOT NULL' : ''}
      ORDER BY w.full_name ASC
      ''',
      [trainingKey],
    );
    final signatureService = AuthorizedSignatureService();
    final trainerId = await signatureService.trainerIdFor(trainingKey);
    final responsibleId =
        await signatureService.responsibleIdFor(trainingKey);
    final trainer = await signatureService.loadSigner(trainerId);
    final responsible = await signatureService.loadSigner(responsibleId);
    final company = await CompanyService().companyForTraining(trainingKey);
    return FsgiRecord(
      course: trainingRows.first['course'] as String? ?? '',
      date: trainingRows.first['training_date'] as String? ?? '',
      hours: trainingRows.first['hours'] as String? ?? '',
      participants: rows
          .map(
            (row) => FsgiParticipant(
              dni: row['dni'] as String? ?? '',
              fullName: row['full_name'] as String? ?? '',
              company: row['company'] as String? ?? '',
              area: row['area'] as String? ?? '',
              position: row['position'] as String? ?? '',
              signaturePng: row['signature_png'] == null
                  ? null
                  : SignatureImageService.normalize(
                      row['signature_png'] as Uint8List,
                    ),
            ),
          )
          .toList(),
      trainer: trainer,
      responsible: responsible,
      company: company,
    );
  }

  Future<Uint8List> generateFsgi(
    String trainingKey, {
    bool signedOnly = false,
  }) async {
    final record = await loadRecord(trainingKey, signedOnly: signedOnly);
    if (signedOnly && record.participants.isEmpty) {
      throw StateError('Todavía no existe ninguna firma para descargar.');
    }
    final document = pw.Document();
    final templateData = await rootBundle.load(
      'assets/templates/fsgi_04_01.png',
    );
    final template = pw.MemoryImage(
      templateData.buffer.asUint8List(
        templateData.offsetInBytes,
        templateData.lengthInBytes,
      ),
    );
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
          margin: pw.EdgeInsets.zero,
          build: (_) => _buildPage(
            record,
            pageParticipants,
            start,
            template,
          ),
        ),
      );
    }
    return document.save();
  }

  Future<String?> saveFsgi(
    String trainingKey, {
    bool signedOnly = false,
  }) async {
    final record = await loadRecord(trainingKey, signedOnly: signedOnly);
    final bytes = await generateFsgi(trainingKey, signedOnly: signedOnly);
    final safeCourse = record.course
        .replaceAll(RegExp(r'[^A-Za-z0-9ÁÉÍÓÚÑáéíóúñ]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final baseName =
        'F-SGI-04-01_${safeCourse.isEmpty ? 'capacitacion' : safeCourse}${signedOnly ? '_firmas_disponibles' : ''}';
    if (Platform.isAndroid) {
      return FileSaver.instance.saveAs(
        name: baseName,
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
    }
    final location = await getSaveLocation(
      suggestedName: '$baseName.pdf',
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
    pw.MemoryImage template,
  ) {
    const rowTop = 102.62;
    const rowHeight = 7.09;
    final widgets = <pw.Widget>[
      pw.Positioned.fill(
        child: pw.Image(template, fit: pw.BoxFit.fill),
      ),
      _cellText(record.course, 68, 56.7, 65, 7.1, size: 7.4, bold: true),
      _cellText(record.trainer?.fullName ?? 'NO ASIGNADO', 68, 63.3, 62, 7,
          size: 7.0, bold: true),
      _cellText(record.trainer?.position ?? '', 68, 70.7, 62, 7,
          size: 6.8, bold: true),
      _cellText(record.company.businessName, 68, 77.8, 62, 7,
          size: 6.8, bold: true),
      _cellText(record.date, 153, 70.7, 39, 7,
          size: 7.0, bold: true, align: pw.TextAlign.center),
      _cellText(_hoursLabel(record.hours), 160.8, 77.5, 33.5, 7.5,
          size: 8.2, bold: true, align: pw.TextAlign.center),
      _cellText(
          (record.company.employeeCount > 0 ? record.company.employeeCount : 78)
              .toString(),
          171,
          51.7,
          29.8,
          5.8,
          size: 8.2,
          bold: true,
          align: pw.TextAlign.center),
      _cellText('X', 36.4, 65.85, 5.2, 5.2,
          size: 8.0, bold: true, align: pw.TextAlign.center),
    ];

    final trainerSignature = record.trainer?.signaturePng;
    if (trainerSignature != null) {
      widgets.add(_image(trainerSignature, 151, 57.2, 36, 12,
          fit: pw.BoxFit.fill));
    }

    for (var slot = 0; slot < 25; slot++) {
      final y = rowTop + slot * rowHeight;
      widgets.add(_whiteBox(9.55, y + .2, 4.62, rowHeight - .4));
      widgets.add(_cellText(
        (start + slot + 1).toString().padLeft(2, '0'),
        9.36,
        y,
        5.0,
        rowHeight,
        size: 7.4,
        bold: true,
        align: pw.TextAlign.center,
      ));
    }

    for (var index = 0; index < participants.length; index++) {
      final person = participants[index];
      final y = rowTop + index * rowHeight;
      widgets.addAll([
        _cellText(person.dni, 14.4, y, 20.65, rowHeight,
            size: 7.0, align: pw.TextAlign.center),
        _cellText(person.fullName, 35.05, y, 49.9, rowHeight, size: 6.4),
        _cellText(person.company, 84.95, y, 17.53, rowHeight,
            size: 5.8, align: pw.TextAlign.center),
        _cellText(person.area, 102.48, y, 27.47, rowHeight,
            size: 6.0, align: pw.TextAlign.center),
        _cellText(person.position, 129.95, y, 42.51, rowHeight,
            size: 6.0, align: pw.TextAlign.center),
      ]);
      if (person.signaturePng != null) {
        widgets.add(_image(person.signaturePng!, 173.2, y + .25, 26, 6.55,
            fit: pw.BoxFit.fill));
      }
    }

    final responsible = record.responsible;
    widgets.addAll([
      _cellText(responsible?.fullName ?? 'CUTIPA QUISPE JHONATHAN', 31.5,
          282.2, 90, 6.0, size: 7.0, bold: true),
      _cellText(responsible?.position ?? 'ASISTENTE SSOMA', 31.5, 289.8, 90,
          6.0, size: 7.0, bold: true),
      _cellText(record.date, 151, 289.8, 40, 6.0,
          size: 7.0, bold: true, align: pw.TextAlign.center),
    ]);
    if (responsible?.signaturePng != null) {
      widgets.add(_image(responsible!.signaturePng!, 147, 277.8, 35, 11.5,
          fit: pw.BoxFit.fill));
    }
    return pw.Stack(children: widgets);
  }

  pw.Widget _cellText(
    String value,
    double x,
    double y,
    double width,
    double height, {
    required double size,
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) =>
      pw.Positioned(
        left: x * PdfPageFormat.mm,
        top: y * PdfPageFormat.mm,
        child: pw.Container(
          width: width * PdfPageFormat.mm,
          height: height * PdfPageFormat.mm,
          padding: const pw.EdgeInsets.symmetric(horizontal: 1.2),
          alignment: align == pw.TextAlign.center
              ? pw.Alignment.center
              : pw.Alignment.centerLeft,
          child: pw.Text(
            value,
            maxLines: 2,
            textAlign: align,
            style: pw.TextStyle(
              fontSize: size,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      );

  pw.Widget _whiteBox(
    double x,
    double y,
    double width,
    double height,
  ) =>
      pw.Positioned(
        left: x * PdfPageFormat.mm,
        top: y * PdfPageFormat.mm,
        child: pw.Container(
          width: width * PdfPageFormat.mm,
          height: height * PdfPageFormat.mm,
          color: PdfColors.white,
        ),
      );

  pw.Widget _image(
    Uint8List bytes,
    double x,
    double y,
    double width,
    double height, {
    pw.BoxFit fit = pw.BoxFit.contain,
  }) =>
      pw.Positioned(
        left: x * PdfPageFormat.mm,
        top: y * PdfPageFormat.mm,
        child: pw.SizedBox(
          width: width * PdfPageFormat.mm,
          height: height * PdfPageFormat.mm,
          child: pw.Image(pw.MemoryImage(bytes), fit: fit),
        ),
      );

  String _hoursLabel(String value) {
    final clean = value
        .trim()
        .replaceAll(RegExp(r'\s*h(?:oras?)?\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\.0$'), '');
    return clean.isEmpty || clean == '—' ? '' : '$clean HORAS';
  }
}
