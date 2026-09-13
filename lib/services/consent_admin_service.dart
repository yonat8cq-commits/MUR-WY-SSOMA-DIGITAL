import 'dart:typed_data';

import '../database/app_database.dart';

class ConsentAdminItem {
  final String dni;
  final String fullName;
  final String company;
  final String position;
  final String? version;
  final DateTime? acceptedAt;
  final Uint8List? signaturePng;

  const ConsentAdminItem({
    required this.dni,
    required this.fullName,
    required this.company,
    required this.position,
    required this.version,
    required this.acceptedAt,
    required this.signaturePng,
  });

  bool get accepted => acceptedAt != null && signaturePng != null;
}

class ConsentAdminService {
  Future<List<ConsentAdminItem>> loadConsents() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT w.dni, w.full_name, w.company, w.position,
             c.version, c.accepted_at, c.signature_png
      FROM trabajadores_importados w
      LEFT JOIN consentimientos c ON c.id = (
        SELECT c2.id
        FROM consentimientos c2
        WHERE c2.dni = w.dni
        ORDER BY c2.accepted_at DESC, c2.id DESC
        LIMIT 1
      )
      ORDER BY w.full_name ASC
    ''');
    return rows.map((row) {
      final acceptedAt = row['accepted_at'] as String?;
      return ConsentAdminItem(
        dni: row['dni'] as String? ?? '',
        fullName: row['full_name'] as String? ?? '',
        company: row['company'] as String? ?? '',
        position: row['position'] as String? ?? '',
        version: row['version'] as String?,
        acceptedAt: acceptedAt == null ? null : DateTime.tryParse(acceptedAt),
        signaturePng: row['signature_png'] as Uint8List?,
      );
    }).toList();
  }
}
