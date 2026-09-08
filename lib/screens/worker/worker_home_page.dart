import 'package:flutter/material.dart';
import '../../services/offline_workflow_service.dart';
import 'training_detail_page.dart';

class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({super.key});

  @override
  State<WorkerHomePage> createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage> {
  int _index = 0;
  bool _signed = false;

  static const _course = TrainingViewData(
    title: 'HIGIENE OCUPACIONAL (AGENTES FÍSICOS, QUÍMICOS, BIOLÓGICOS) DISPOSICIÓN DE RESIDUOS SÓLIDOS',
    date: '01/02/2026',
    hours: '2 horas',
    provider: 'TECSUP',
    deadline: '13/03/2026',
  );

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final signed = await OfflineWorkflowService.instance
        .trainingWasSigned('194076_1_2026-02-01');
    if (mounted) setState(() => _signed = signed);
  }

  Future<void> _openTraining() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const TrainingDetailPage(training: _course),
      ),
    );
    if (result == true) {
      setState(() => _signed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MUR WY SSOMA DIGITAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text('Portal del trabajador', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _index == 0 ? _pending(context) : _history(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(icon: Badge(label: const Text('1'), isLabelVisible: !_signed, child: const Icon(Icons.pending_actions_outlined)), selectedIcon: const Icon(Icons.pending_actions), label: 'Pendientes'),
          const NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }

  Widget _header(String title, String subtitle) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Hola, Luis Ángel', style: TextStyle(fontSize: 14, color: Color(0xFF626B7A))),
      const SizedBox(height: 6),
      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: Color(0xFF626B7A))),
    ]),
  );

  Widget _pending(BuildContext context) => ListView(children: [
    _header('Capacitaciones pendientes', 'Confirma tu participación y firma antes del vencimiento.'),
    if (_signed)
      const Padding(
        padding: EdgeInsets.all(28),
        child: Column(children: [
          Icon(Icons.task_alt, size: 72, color: Color(0xFF16743B)),
          SizedBox(height: 14),
          Text('No tienes firmas pendientes', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('Tu firma quedó guardada localmente y está pendiente de sincronización.', textAlign: TextAlign.center),
        ]),
      )
    else Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openTraining,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Chip(label: Text('PENDIENTE'), avatar: Icon(Icons.schedule, size: 18)),
                Spacer(),
                Text('Vence 13/03/2026', style: TextStyle(color: Color(0xFF9A5D00), fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              Text(_course.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              const Row(children: [Icon(Icons.calendar_today_outlined, size: 18), SizedBox(width: 8), Text('01/02/2026  •  2 horas')]),
              const SizedBox(height: 8),
              const Row(children: [Icon(Icons.school_outlined, size: 18), SizedBox(width: 8), Text('TECSUP')]),
              const SizedBox(height: 16),
              const Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('REVISAR Y FIRMAR', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(width: 6), Icon(Icons.arrow_forward)]),
            ]),
          ),
        ),
      ),
    ),
  ]);

  Widget _history(BuildContext context) => ListView(children: [
    _header('Mi historial', 'Consulta las capacitaciones que ya confirmaste.'),
    if (_signed)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Card(
          elevation: 0,
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.all(18),
            leading: const CircleAvatar(backgroundColor: Color(0xFFFFF2CC), child: Icon(Icons.cloud_off, color: Color(0xFF9A5D00))),
            title: Text(_course.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('01/02/2026 • Guardado sin conexión'),
          ),
        ),
      ),
    const Padding(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        color: Colors.white,
        child: ListTile(
          contentPadding: EdgeInsets.all(18),
          leading: CircleAvatar(backgroundColor: Color(0xFFE4F5EA), child: Icon(Icons.check, color: Color(0xFF16743B))),
          title: Text('INDUCCIÓN GENERAL DE SEGURIDAD', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('15/01/2026 • Firmado'),
          trailing: Icon(Icons.chevron_right),
        ),
      ),
    ),
  ]);
}
