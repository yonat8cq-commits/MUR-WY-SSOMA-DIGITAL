import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'audit_service.dart';

class BackupSummary {
  final DateTime createdAt;
  final int tables;
  final int records;

  const BackupSummary({
    required this.createdAt,
    required this.tables,
    required this.records,
  });
}

class BackupService {
  static const _format = 'MUR_WY_SSOMA_BACKUP';
  static const _version = 1;
  static const _tables = [
    'trabajadores',
    'capacitaciones',
    'inspecciones',
    'app_settings',
    'consentimientos',
    'confirmaciones_capacitacion',
    'importaciones_tecsup',
    'trabajadores_importados',
    'capacitaciones_importadas',
    'participantes_capacitacion',
    'firmas_autorizadas',
    'firmantes_capacitacion',
    'control_documental',
    'versiones_registro',
    'empresas',
    'empresa_capacitacion',
    'documentos_historicos',
    'auditoria',
    'sync_outbox',
    'sync_metadata',
  ];

  static const _protectedSettings = {
    'admin_password_hash',
    'admin_password_salt',
    'admin_recovery_hash',
    'admin_recovery_salt',
    'admin_password_updated_at',
  };

  Future<String?> createBackup() async {
    final db = await AppDatabase.instance.database;
    final tables = <String, List<Map<String, Object?>>>{};
    var total = 0;
    for (final name in _tables) {
      final exists = await _tableExists(db, name);
      if (!exists) continue;
      var rows = await db.query(name);
      if (name == 'app_settings') {
        rows = rows
            .where((row) => !_protectedSettings.contains(row['setting_key']))
            .toList();
      }
      tables[name] = rows.map(_encodeRow).toList();
      total += rows.length;
    }
    final now = DateTime.now();
    final payload = jsonEncode({
      'format': _format,
      'version': _version,
      'created_at': now.toUtc().toIso8601String(),
      'tables': tables,
    });
    final stamp = '${now.year}${_two(now.month)}${_two(now.day)}_'
        '${_two(now.hour)}${_two(now.minute)}';
    final location = await getSaveLocation(
      suggestedName: 'Respaldo_MUR_WY_SSOMA_$stamp.murwy',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Respaldo MUR WY', extensions: ['murwy']),
      ],
    );
    if (location == null) return null;
    await XFile.fromData(
      Uint8List.fromList(utf8.encode(payload)),
      mimeType: 'application/json',
      name: location.path.split('/').last,
    ).saveTo(location.path);
    await AuditService().record(
      category: 'SEGURIDAD',
      action: 'COPIA DE SEGURIDAD GENERADA',
      detail: 'Se respaldaron ${tables.length} tablas y $total registros.',
      targetType: 'RESPALDO',
      targetId: location.path.split('/').last,
    );
    return location.path;
  }

  Future<BackupSummary?> inspectBackup() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Respaldo MUR WY', extensions: ['murwy']),
      ],
    );
    if (file == null) return null;
    final payload = _parse(await file.readAsBytes());
    final tables = payload['tables'] as Map<String, dynamic>;
    final records = tables.values.fold<int>(
      0,
      (sum, rows) => sum + (rows as List<dynamic>).length,
    );
    _pendingPayload = payload;
    _pendingFileName = file.name;
    return BackupSummary(
      createdAt: DateTime.parse(payload['created_at'] as String).toLocal(),
      tables: tables.length,
      records: records,
    );
  }

  Map<String, dynamic>? _pendingPayload;
  String? _pendingFileName;

  Future<void> restoreInspectedBackup() async {
    final payload = _pendingPayload;
    if (payload == null) throw StateError('No existe un respaldo validado.');
    final tables = payload['tables'] as Map<String, dynamic>;
    final db = await AppDatabase.instance.database;
    await db.transaction((transaction) async {
      for (final name in _tables.reversed) {
        if (tables.containsKey(name) && name != 'app_settings') {
          await transaction.delete(name);
        }
      }
      if (tables.containsKey('app_settings')) {
        for (final row in tables['app_settings'] as List<dynamic>) {
          final decoded = _decodeRow(row as Map<String, dynamic>);
          final key = decoded['setting_key'];
          if (key is String && !_protectedSettings.contains(key)) {
            await transaction.insert(
              'app_settings',
              decoded,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
      for (final name in _tables) {
        if (name == 'app_settings' || !tables.containsKey(name)) continue;
        for (final row in tables[name] as List<dynamic>) {
          await transaction.insert(
            name,
            _decodeRow(row as Map<String, dynamic>),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
    await AuditService().record(
      category: 'SEGURIDAD',
      action: 'COPIA DE SEGURIDAD RESTAURADA',
      detail: 'Se restauró un respaldo validado. Las credenciales del administrador se conservaron.',
      targetType: 'RESPALDO',
      targetId: _pendingFileName,
    );
    _pendingPayload = null;
    _pendingFileName = null;
  }

  Map<String, dynamic> _parse(Uint8List bytes) {
    try {
      final payload = jsonDecode(utf8.decode(bytes));
      if (payload is! Map<String, dynamic> ||
          payload['format'] != _format ||
          payload['version'] != _version ||
          payload['tables'] is! Map<String, dynamic> ||
          payload['created_at'] is! String) {
        throw const FormatException('Formato de respaldo no reconocido.');
      }
      final tables = payload['tables'] as Map<String, dynamic>;
      if (tables.keys.any((name) => !_tables.contains(name))) {
        throw const FormatException('El respaldo contiene tablas no permitidas.');
      }
      return payload;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('El archivo está dañado o no es un respaldo válido.');
    }
  }

  Map<String, Object?> _encodeRow(Map<String, Object?> row) => row.map(
        (key, value) => MapEntry(
          key,
          value is Uint8List ? {'__murwy_blob__': base64Encode(value)} : value,
        ),
      );

  Map<String, Object?> _decodeRow(Map<String, dynamic> row) => row.map(
        (key, value) => MapEntry(
          key,
          value is Map<String, dynamic> && value.containsKey('__murwy_blob__')
              ? base64Decode(value['__murwy_blob__'] as String)
              : value,
        ),
      );

  Future<bool> _tableExists(Database db, String name) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [name],
    );
    return rows.isNotEmpty;
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
