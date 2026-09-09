import 'package:flutter/material.dart';
import '../../services/offline_workflow_service.dart';
import '../../services/worker_data_service.dart';
import '../../services/notification_service.dart';
import 'training_detail_page.dart';

class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({super.key});

  @override
  State<WorkerHomePage> createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage> {
  int _index = 0;
  bool _loading = true;
  WorkerProfile? _profile;
  List<AssignedTraining> _trainings = [];
  bool _sharedDevice = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dni = await OfflineWorkflowService.instance.currentDni;
    if (dni == null) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      }
      return;
    }
    final shared = await OfflineWorkflowService.instance.sharedDeviceMode;
    final service = WorkerDataService();
    final profile = await service.loadProfile(dni);
    final trainings = await service.loadTrainings(dni);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _trainings = trainings;
      _sharedDevice = shared;
      _loading = false;
    });
    await NotificationService.instance.showWorkerReminder(trainings);
  }

  Future<void> _logout() async {
    await OfflineWorkflowService.instance.closeSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  Future<void> _openTraining(AssignedTraining training) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingDetailPage(
          training: TrainingViewData(
            key: training.key,
            title: training.course,
            date: training.date,
            hours: 'Según registro TECSUP',
            provider: 'TECSUP',
            deadline: _date(training.deadline),
          ),
        ),
      ),
    );
    if (result == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _trainings.where((item) => !item.signed).toList();
    final signed = _trainings.where((item) => item.signed).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MUR WY SSOMA DIGITAL',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('Portal del trabajador',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _index == 0
              ? _trainingList(
                  title: 'Capacitaciones pendientes',
                  subtitle:
                      'Confirma tu participación y firma antes del vencimiento.',
                  items: pending,
                  emptyTitle: 'No tienes firmas pendientes',
                  emptyMessage:
                      'Cuando SSOMA publique una capacitación aparecerá aquí.',
                )
              : _trainingList(
                  title: 'Mi historial',
                  subtitle: 'Consulta las capacitaciones que ya confirmaste.',
                  items: signed,
                  emptyTitle: 'Todavía no tienes capacitaciones firmadas',
                  emptyMessage:
                      'Las capacitaciones firmadas aparecerán en este historial.',
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: Badge(
              label: Text(pending.length.toString()),
              isLabelVisible: pending.isNotEmpty,
              child: const Icon(Icons.pending_actions_outlined),
            ),
            selectedIcon: const Icon(Icons.pending_actions),
            label: 'Pendientes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
        ],
      ),
    );
  }

  Widget _trainingList({
    required String title,
    required String subtitle,
    required List<AssignedTraining> items,
    required String emptyTitle,
    required String emptyMessage,
  }) {
    return ListView(
      children: [
        _header(title, subtitle),
        if (_sharedDevice)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Card(
              elevation: 0,
              color: Color(0xFFFFF2CC),
              child: ListTile(
                leading: Icon(Icons.phonelink_lock_outlined),
                title: Text(
                  'Modo dispositivo compartido',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Al finalizar una firma volverás al ingreso para proteger tus datos.',
                ),
              ),
            ),
          ),
        if (_profile == null)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Card(
              elevation: 0,
              color: Color(0xFFFFF5D6),
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Este DNI aún no tiene información importada. Ingresa como '
                  'administrador y carga primero el Excel TECSUP.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                const Icon(Icons.task_alt,
                    size: 72, color: Color(0xFF16743B)),
                const SizedBox(height: 14),
                Text(emptyTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(emptyMessage, textAlign: TextAlign.center),
              ],
            ),
          )
        else
          ...items.map(_trainingCard),
      ],
    );
  }

  Widget _header(String title, String subtitle) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _profile == null
                  ? 'Trabajador'
                  : 'Hola, ' + _displayName(_profile!.fullName),
              style:
                  const TextStyle(fontSize: 14, color: Color(0xFF626B7A)),
            ),
            const SizedBox(height: 6),
            Text(title,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(color: Color(0xFF626B7A))),
          ],
        ),
      );

  Widget _trainingCard(AssignedTraining training) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Card(
          elevation: 0,
          color: Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: training.canSign ? () => _openTraining(training) : null,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    avatar: Icon(
                      training.signed ? Icons.check_circle : Icons.schedule,
                      size: 18,
                    ),
                    label: Text(training.status),
                  ),
                  const SizedBox(height: 10),
                  Text(training.course,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(training.date)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.event_busy_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text('Plazo: ${_date(training.deadline)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.school_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('TECSUP'),
                    ],
                  ),
                  if (training.canSign) ...[
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('REVISAR Y FIRMAR',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  String _displayName(String fullName) {
    final clean = fullName.trim();
    if (clean.isEmpty) return 'Trabajador';
    final parts = clean.split(',');
    return parts.length > 1 ? parts.last.trim() : clean;
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
