import 'package:flutter/material.dart';

import '../../services/audit_service.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final _service = AuditService();
  final _search = TextEditingController();
  List<AuditEntry> _entries = const [];
  String _category = 'TODAS';
  bool _loading = true;
  bool _exporting = false;

  static const _categories = ['TODAS', 'SEGURIDAD', 'IMPORTACIÓN', 'USUARIOS', 'DOCUMENTOS'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _service.load(category: _category, query: _search.text);
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final path = await _service.exportExcel(_entries);
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte de auditoría guardado correctamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registro de auditoría')),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text('Trazabilidad de acciones administrativas',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Los eventos son de solo lectura y conservan fecha, responsable y detalle.'),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Buscar acción, detalle o DNI',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward)),
            ),
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: _categories.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) { if (value != null) { _category = value; _load(); } },
            )),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _exporting || _entries.isEmpty ? null : _export,
              icon: const Icon(Icons.download_outlined),
              label: Text(_exporting ? 'GENERANDO…' : 'EXCEL'),
            ),
          ]),
        ]),
      ),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _entries.isEmpty
          ? const Center(child: Text('No existen eventos para este filtro.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final item = _entries[index];
                return Card(child: ListTile(
                  leading: CircleAvatar(child: Icon(_icon(item.category))),
                  title: Text(item.action, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${item.detail}\n${item.actor} • ${_date(item.occurredAt)}'),
                  isThreeLine: true,
                  trailing: Text(item.category, style: const TextStyle(fontSize: 10)),
                ));
              },
            )),
    ]),
  );

  IconData _icon(String category) {
    switch (category) {
      case 'SEGURIDAD': return Icons.security_outlined;
      case 'IMPORTACIÓN': return Icons.upload_file_outlined;
      case 'USUARIOS': return Icons.manage_accounts_outlined;
      default: return Icons.description_outlined;
    }
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
