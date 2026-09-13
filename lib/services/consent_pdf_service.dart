import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'consent_admin_service.dart';

class ConsentPdfService {
  static const _consentText =
      'Autorizo a MUR WY S.A.C. a registrar y utilizar mi firma electrónica '
      'exclusivamente como evidencia de participación en inducciones y '
      'capacitaciones SSOMA. Cada uso requerirá mi confirmación. La evidencia '
      'conservará mi DNI, fecha, hora y versión del consentimiento. Puedo '
      'solicitar información sobre el tratamiento de mis datos al responsable '
      'SSOMA. Esta autorización no permite utilizar mi firma para documentos '
      'distintos a los registros expresamente confirmados por mí.';

  Future<Uint8List> generate(ConsentAdminItem item) async {
    if (!item.accepted || item.acceptedAt == null) {
      throw StateError('El trabajador aún no aceptó el consentimiento.');
    }
    final document = pw.Document();
    final accepted = item.acceptedAt!.toLocal();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(42),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 14),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF1F4E78),
              ),
              child: pw.Text(
                'MUR WY SSOMA DIGITAL',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 28),
            pw.Text(
              'AUTORIZACIÓN DE USO DE FIRMA ELECTRÓNICA\nPARA REGISTROS SSOMA',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 28),
            _dataRow('Apellidos y nombres', item.fullName),
            _dataRow('DNI', item.dni),
            _dataRow('Empresa', item.company.isEmpty ? 'MUR WY S.A.C.' : item.company),
            _dataRow('Cargo', item.position),
            _dataRow('Fecha de aceptación', _date(accepted)),
            _dataRow('Hora de aceptación', _time(accepted)),
            _dataRow('Versión del consentimiento', item.version ?? '1.0'),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey500),
              ),
              child: pw.Text(
                _consentText,
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 5),
              ),
            ),
            pw.SizedBox(height: 28),
            pw.Center(
              child: pw.Container(
                width: 260,
                height: 120,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFF123EBA)),
                ),
                child: pw.Image(
                  pw.MemoryImage(item.signaturePng!),
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Firma electrónica del trabajador',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey500),
            pw.Text(
              'Evidencia generada por MUR WY SSOMA DIGITAL. Documento de consulta exclusiva del super administrador.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }

  Future<String?> save(ConsentAdminItem item) async {
    final bytes = await generate(item);
    final safeName = item.fullName
        .replaceAll(RegExp(r'[^A-Za-z0-9ÁÉÍÓÚÑáéíóúñ]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final location = await getSaveLocation(
      suggestedName: 'Consentimiento_${item.dni}_${safeName.isEmpty ? 'trabajador' : safeName}.pdf',
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

  pw.Widget _dataRow(String label, String value) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
        ),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 150,
              child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
          ],
        ),
      );

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
}
