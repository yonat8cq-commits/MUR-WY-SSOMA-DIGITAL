import 'package:flutter/material.dart';

import '../../services/consent_admin_service.dart';
import '../../services/consent_pdf_service.dart';

class ConsentsAdminPage extends StatefulWidget {
  const ConsentsAdminPage({super.key});

  @override
  State<ConsentsAdminPage> createState() => _ConsentsAdminPageState();
}

class _ConsentsAdminPageState extends State<ConsentsAdminPage> {
  final _service = ConsentAdminService();
  final _pdf = ConsentPdfService();
  final _search = TextEditingController();
  List<ConsentAdminItem> _items = [];
  bool _loading = true;
  String _filter = 'TODOS';
  String? _savingDni;

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
    final items = await _service.loadConsents();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _download(ConsentAdminItem item) async {
    setState(() => _savingDni = item.dni);
    try {
      final path = await _pdf.save(item);
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Consentimiento guardado en $path')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingDni = null);
    }
  }

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    final date = '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date • $time';
  }

  @override
  Widget build(BuildContext context) {
    final accepted = _items.where((item) => item.accepted).length;
    final query = _search.text.trim().toLowerCase();
    final visible = _items.where((item) {
      final matchesSearch = item.dni.contains(query) ||
          item.fullName.toLowerCase().contains(query) ||
          item.company.toLowerCase().contains(query);
      final matchesFilter = _filter == 'TODOS' ||
          (_filter == 'ACEPTADOS' && item.accepted) ||
          (_filter == 'PENDIENTES' && !item.accepted);
      return matchesSearch && matchesFilter;
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consentimientos'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Actualizar'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text('Control de autorizaciones', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                  'Consulta exclusiva del super administrador Jhonathan Cutipa.',
                  style: TextStyle(color: Color(0xFF626B7A)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _summary('Aceptados', accepted, const Color(0xFF16743B))),
                    const SizedBox(width: 10),
                    Expanded(child: _summary('Pendientes', _items.length - accepted, const Color(0xFF9B5C00))),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Buscar por DNI, nombre o empresa',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['TODOS', 'ACEPTADOS', 'PENDIENTES'].map((filter) {
                    return ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No hay resultados para este filtro.'))),
                ...visible.map((item) => _consentCard(item)),
              ],
            ),
    );
  }

  Widget _summary(String label, int value, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _consentCard(ConsentAdminItem item) => Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 10),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: item.accepted ? const Color(0xFFE4F5EA) : const Color(0xFFFFF0D8),
            child: Icon(item.accepted ? Icons.verified_user : Icons.hourglass_top),
          ),
          title: Text(item.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${item.dni} • ${item.accepted ? 'ACEPTADO' : 'PENDIENTE'}'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${item.company} • ${item.position}'),
              subtitle: Text(item.accepted
                  ? 'Aceptado: ${_dateTime(item.acceptedAt!)} • Versión ${item.version}'
                  : 'El trabajador aún debe aceptar y registrar su firma.'),
            ),
            if (item.signaturePng != null)
              Container(
                height: 110,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFF123EBA)), borderRadius: BorderRadius.circular(10)),
                child: Image.memory(item.signaturePng!, fit: BoxFit.contain),
              ),
            if (item.accepted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _savingDni == null ? () => _download(item) : null,
                  icon: _savingDni == item.dni
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('DESCARGAR AUTORIZACIÓN PDF'),
                ),
              ),
            ],
          ],
        ),
      );
}
