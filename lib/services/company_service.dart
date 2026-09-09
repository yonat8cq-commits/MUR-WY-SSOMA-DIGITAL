import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class CompanyProfile {
  final String id;
  final String businessName;
  final String ruc;
  final String address;
  final String economicActivity;
  final int employeeCount;
  final Uint8List? logoPng;
  final bool active;

  const CompanyProfile({
    required this.id,
    required this.businessName,
    required this.ruc,
    required this.address,
    required this.economicActivity,
    required this.employeeCount,
    required this.logoPng,
    required this.active,
  });
}

class CompanyService {
  Future<List<CompanyProfile>> loadCompanies() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'empresas',
      where: 'active = 1',
      orderBy: 'business_name ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<CompanyProfile> companyForTraining(String trainingKey) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT e.* FROM empresas e
      INNER JOIN empresa_capacitacion ec ON ec.company_id = e.company_id
      WHERE ec.training_key = ?
      LIMIT 1
      ''',
      [trainingKey],
    );
    if (rows.isNotEmpty) return _fromRow(rows.first);
    final defaults = await db.query(
      'empresas',
      where: 'company_id = ?',
      whereArgs: ['mur_wy'],
      limit: 1,
    );
    return _fromRow(defaults.first);
  }

  Future<String> companyIdForTraining(String trainingKey) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'empresa_capacitacion',
      columns: ['company_id'],
      where: 'training_key = ?',
      whereArgs: [trainingKey],
      limit: 1,
    );
    return rows.isEmpty ? 'mur_wy' : rows.first['company_id'] as String;
  }

  Future<void> assignToTraining(String trainingKey, String companyId) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'empresa_capacitacion',
      {
        'training_key': trainingKey,
        'company_id': companyId,
        'assigned_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> save({
    String? id,
    required String businessName,
    required String ruc,
    required String address,
    required String economicActivity,
    required int employeeCount,
    Uint8List? logoPng,
  }) async {
    final db = await AppDatabase.instance.database;
    final companyId = id ??
        '${DateTime.now().microsecondsSinceEpoch}_${businessName.hashCode.abs()}';
    final current = id == null
        ? <Map<String, Object?>>[]
        : await db.query(
            'empresas',
            columns: ['logo_png'],
            where: 'company_id = ?',
            whereArgs: [id],
            limit: 1,
          );
    await db.insert(
      'empresas',
      {
        'company_id': companyId,
        'business_name': businessName,
        'ruc': ruc,
        'address': address,
        'economic_activity': economicActivity,
        'employee_count': employeeCount,
        'logo_png': logoPng ??
            (current.isEmpty ? null : current.first['logo_png'] as Uint8List?),
        'active': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  CompanyProfile _fromRow(Map<String, Object?> row) => CompanyProfile(
        id: row['company_id'] as String,
        businessName: row['business_name'] as String? ?? '',
        ruc: row['ruc'] as String? ?? '',
        address: row['address'] as String? ?? '',
        economicActivity: row['economic_activity'] as String? ?? '',
        employeeCount: row['employee_count'] as int? ?? 0,
        logoPng: row['logo_png'] as Uint8List?,
        active: (row['active'] as int? ?? 1) == 1,
      );
}
