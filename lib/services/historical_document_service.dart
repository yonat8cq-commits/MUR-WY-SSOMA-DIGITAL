import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class HistoricalDocument {
  final int id;
  final String title;
  final String course;
  final String trainingDate;
  final String company;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final DateTime importedAt;

  const HistoricalDocument({
    required this.id,
    required this.title,
    required this.course,
    required this.trainingDate,
    required this.company,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.importedAt,
  });
}

class HistoricalDocumentService {
  static const acceptedTypes = XTypeGroup(
    label: 'Documento de capacitación',
    extensions: ['pdf', 'xlsx', 'xls', 'docx', 'doc', 'png', 'jpg', 'jpeg'],
  );

  Future<XFile?> selectFile() => openFile(
        acceptedTypeGroups: const [acceptedTypes],
      );

  Future<void> importDocument({
    required XFile file,
    required String title,
    required String course,
    required String trainingDate,
    required String company,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('El archivo seleccionado está vacío.');
    final db = await AppDatabase.instance.database;
    await db.insert('documentos_historicos', {
      'title': title.trim(),
      'course': course.trim(),
      'training_date': trainingDate.trim(),
      'company': company.trim(),
      'file_name': file.name,
      'mime_type': file.mimeType ?? _mimeType(file.name),
      'file_bytes': bytes,
      'imported_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<HistoricalDocument>> loadDocuments() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT id, title, course, training_date, company, file_name, mime_type,
             length(file_bytes) AS file_size, imported_at
      FROM documentos_historicos
      ORDER BY training_date DESC, imported_at DESC
    ''');
    return rows.map((row) => HistoricalDocument(
          id: row['id'] as int,
          title: row['title'] as String? ?? '',
          course: row['course'] as String? ?? '',
          trainingDate: row['training_date'] as String? ?? '',
          company: row['company'] as String? ?? '',
          fileName: row['file_name'] as String? ?? '',
          mimeType: row['mime_type'] as String? ?? 'application/octet-stream',
          fileSize: row['file_size'] as int? ?? 0,
          importedAt: DateTime.tryParse(row['imported_at'] as String? ?? '') ?? DateTime.now(),
        )).toList();
  }

  Future<String?> saveCopy(HistoricalDocument document) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'documentos_historicos',
      columns: ['file_bytes'],
      where: 'id = ?',
      whereArgs: [document.id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('El documento ya no existe.');
    final location = await getSaveLocation(suggestedName: document.fileName);
    if (location == null) return null;
    final file = XFile.fromData(
      rows.first['file_bytes'] as Uint8List,
      mimeType: document.mimeType,
      name: document.fileName,
    );
    await file.saveTo(location.path);
    return location.path;
  }

  Future<void> deleteDocument(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('documentos_historicos', where: 'id = ?', whereArgs: [id]);
  }

  String _mimeType(String name) {
    final extension = name.split('.').last.toLowerCase();
    const types = {
      'pdf': 'application/pdf',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'xls': 'application/vnd.ms-excel',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'doc': 'application/msword',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
    };
    return types[extension] ?? 'application/octet-stream';
  }
}
