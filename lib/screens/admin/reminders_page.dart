import 'package:flutter/material.dart';

import '../../services/reminder_service.dart';
import 'training_progress_detail_page.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<TrainingReminder> _alerts = [];
  bool _loading = true;
  String _filter = 'TODOS';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final alerts = await ReminderService().loadAlerts();
    if (!mounted) return;
    setState(() {
      _alerts = alerts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final overdue = _alerts.where((item) => item.level == 'VENCIDO').length;
    final critical = _alerts.where((item) => item.level == 'CRÍTICO').length;
    final visible = _alerts.where((item) {
      if (_filter == 'TODOS') return true;
      if (_filter == 'URGENTES') {
        return item.level == 'VENCIDO' || item.level == 'CRÍTICO';
      }
      return item.level == _filter;
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas de firmas'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Actualizar'),
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
                    'Recordatorios del panel',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Prioriza las firmas pendientes según el plazo de 160 días.',
                    style: TextStyle(color: Color(0xFF626B7A)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _summary('Vencidos', overdue, const Color(0xFFB42318))),
                      const SizedBox(width: 10),
                      Expanded(child: _summary('Hasta 5 días', critical, const Color(0xFFD97706))),
                      const SizedBox(width: 10),
                      Expanded(child: _summary('Pendientes', _alerts.fold(0, (total, item) => total + item.training.pending), const Color(0xFF1F4E78))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['TODOS', 'URGENTES', 'PRÓXIMO', 'EN PLAZO'].map((filter) {
                      return ChoiceChip(
                        label: Text(filter),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.task_alt, size: 58, color: Color(0xFF16743B)),
                            SizedBox(height: 10),
                            Text('No existen alertas en esta categoría.', textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ...visible.map(_alertCard),
                ],
              ),
            ),
    );
  }

  Widget _summary(String label, int value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _alertCard(TrainingReminder reminder) {
    final training = reminder.training;
    final color = _color(reminder.level);
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrainingProgressDetailPage(training: training),
            ),
          );
          await _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(.12),
                child: Icon(Icons.notifications_active_outlined, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(training.course, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text('${training.date} • ${training.pending} de ${training.total} pendientes'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(_deadlineText(reminder), style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _deadlineText(TrainingReminder reminder) {
    if (reminder.daysRemaining < 0) {
      final days = -reminder.daysRemaining;
      return 'VENCIDO HACE $days ${days == 1 ? 'DÍA' : 'DÍAS'}';
    }
    if (reminder.daysRemaining == 0) return 'VENCE HOY';
    return '${reminder.level} • QUEDAN ${reminder.daysRemaining} DÍAS';
  }

  Color _color(String level) {
    if (level == 'VENCIDO') return const Color(0xFFB42318);
    if (level == 'CRÍTICO') return const Color(0xFFD97706);
    if (level == 'PRÓXIMO') return const Color(0xFF9B6A00);
    return const Color(0xFF1F4E78);
  }
}
