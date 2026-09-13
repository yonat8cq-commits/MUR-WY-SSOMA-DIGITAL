import 'package:flutter/material.dart';
import '../../services/admin_tracking_service.dart';
import '../../services/tracking_report_service.dart';
import 'training_progress_detail_page.dart';

class SignatureTrackingPage extends StatefulWidget {
  const SignatureTrackingPage({super.key});

  @override
  State<SignatureTrackingPage> createState() => _SignatureTrackingPageState();
}

class _SignatureTrackingPageState extends State<SignatureTrackingPage> {
  final _search = TextEditingController();
  List<TrainingProgress> _items = [];
  bool _loading = true;
  bool _exporting = false;

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
    final items = await AdminTrackingService().loadTrainings();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _exportReport() async {
    setState(() => _exporting = true);
    try {
      final path = await TrackingReportService().generateAndSave();
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reporte guardado en: $path')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el reporte: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _items
        .where((item) =>
            item.course.toLowerCase().contains(query) ||
            item.date.toLowerCase().contains(query))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento de firmas'),
        actions: [
          IconButton(
            tooltip: 'Descargar reporte Excel',
            onPressed: _loading || _exporting ? null : _exportReport,
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const Text(
                    'Avance por capacitación',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selecciona un curso para revisar firmados y pendientes.',
                    style: TextStyle(color: Color(0xFF626B7A)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _exporting ? null : _exportReport,
                    icon: const Icon(Icons.table_view_outlined),
                    label: Text(
                      _exporting
                          ? 'GENERANDO REPORTE...'
                          : 'DESCARGAR REPORTE EXCEL',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Buscar por curso o fecha',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 68),
                          SizedBox(height: 12),
                          Text(
                            'No existen capacitaciones para mostrar',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...visible.map(_progressCard),
                ],
              ),
            ),
    );
  }

  Widget _progressCard(TrainingProgress item) {
    final percent = (item.ratio * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TrainingProgressDetailPage(training: item),
              ),
            );
            await _load();
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.course,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(item.date,
                    style: const TextStyle(color: Color(0xFF626B7A))),
                const SizedBox(height: 8),
                Chip(
                  avatar: Icon(_statusIcon(item.status), size: 17),
                  label: Text(item.status),
                  backgroundColor: _statusColor(item.status),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: item.ratio,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(10),
                  backgroundColor: const Color(0xFFE6E9EE),
                  color: item.pending == 0
                      ? const Color(0xFF16743B)
                      : const Color(0xFFF3B41B),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(percent.toString() + '%',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    Text('Firmaron: ' + item.signed.toString()),
                    Text('Pendientes: ' + item.pending.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('Vence: ${_date(item.deadline)}'),
                    if (item.version > 0) Text('Versión: ${item.version}'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    if (status == 'CERRADO') return const Color(0xFFDDE7F8);
    if (status == 'COMPLETO') return const Color(0xFFE4F5EA);
    if (status == 'VENCIDO') return const Color(0xFFFFE1E1);
    return const Color(0xFFFFF2CC);
  }

  IconData _statusIcon(String status) {
    if (status == 'CERRADO') return Icons.lock_outline;
    if (status == 'COMPLETO') return Icons.check_circle_outline;
    if (status == 'VENCIDO') return Icons.warning_amber_rounded;
    return Icons.schedule;
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
