import 'dart:typed_data';
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../database/app_database.dart';
import 'authorized_signature_service.dart';
import 'company_service.dart';

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
  final CompanyProfile company;

  const FsgiRecord({
    required this.course,
    required this.date,
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
        ${signedOnly ? 'AND f.record_key IS NOT NULL' : ''}
      ORDER BY w.full_name ASC
      ''',
      [trainingKey],
    );
    final signatureService = AuthorizedSignatureService();
    final trainerId = await signatureService.trainerIdFor(trainingKey);
    final trainer = await signatureService.loadSigner(trainerId);
    final responsible = await signatureService.loadSigner('jhonathan');
    final company = await CompanyService().companyForTraining(trainingKey);
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
    final widgets = <pw.Widget>[
      pw.Positioned.fill(
        child: pw.Image(template, fit: pw.BoxFit.fill),
      ),
      _text(record.course, 68, 60.5, width: 65, size: 7.5, bold: true),
      _text(record.trainer?.fullName ?? 'NO ASIGNADO', 68, 68.7,
          width: 62, size: 6.5),
      _text(record.trainer?.position ?? '', 68, 76.2,
          width: 62, size: 6.5),
      _text(record.company.businessName, 68, 83.6, width: 62, size: 6.5),
      _text(record.date, 153, 76.2, width: 39, size: 6.5),
      _text('X', 37.7, 69.9, width: 4, size: 8, bold: true),
    ];

    final trainerSignature = record.trainer?.signaturePng;
    if (trainerSignature != null) {
      widgets.add(_image(trainerSignature, 149, 64.2, 43, 10));
    }

    for (var index = 0; index < participants.length; index++) {
      final person = participants[index];
      final y = 102.6 + index * 7.12;
      widgets.addAll([
        _text((start + index + 1).toString().padLeft(2, '0'), 8.5, y,
            width: 6.6, size: 5.1, align: pw.TextAlign.center),
        _text(person.dni, 15.2, y, width: 20, size: 5.1,
            align: pw.TextAlign.center),
        _text(person.fullName, 35.8, y, width: 49, size: 5.1),
        _text(person.company, 85.2, y, width: 17.5, size: 5.1),
        _text(person.area, 103, y, width: 27.2, size: 5.1),
        _text(person.position, 130.5, y, width: 42, size: 5.1),
      ]);
      if (person.signaturePng != null) {
        widgets.add(_image(person.signaturePng!, 174.5, y - 4.9, 24, 5.8));
      }
    }

    final responsible = record.responsible;
    widgets.addAll([
      _text(responsible?.fullName ?? 'CUTIPA QUISPE JHONATHAN', 31.5, 283.7,
          width: 96, size: 5.8),
      _text(responsible?.position ?? 'ASISTENTE SSOMA', 31.5, 290.7,
          width: 96, size: 5.8),
      _text(record.date, 151, 290.7, width: 40, size: 5.8),
    ]);
    if (responsible?.signaturePng != null) {
      widgets.add(_image(responsible!.signaturePng!, 151, 280.7, 39, 9));
    }
    return pw.Stack(children: widgets);
  }

  pw.Widget _text(
    String value,
    double x,
    double y, {
    required double width,
    required double size,
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) =>
      pw.Positioned(
        left: x * PdfPageFormat.mm,
        top: y * PdfPageFormat.mm,
        width: width * PdfPageFormat.mm,
        child: pw.Text(
          value,
          maxLines: 2,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  pw.Widget _image(
    Uint8List bytes,
    double x,
    double y,
    double width,
    double height,
  ) =>
      pw.Positioned(
        left: x * PdfPageFormat.mm,
        top: y * PdfPageFormat.mm,
        width: width * PdfPageFormat.mm,
        height: height * PdfPageFormat.mm,
        child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
      );
}
