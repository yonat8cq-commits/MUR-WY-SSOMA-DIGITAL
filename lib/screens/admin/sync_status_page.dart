import 'package:flutter/material.dart';

import '../../services/sync_status_service.dart';

class SyncStatusPage extends StatefulWidget {
  const SyncStatusPage({super.key});

  @override
  State<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends State<SyncStatusPage> {
  SyncStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await SyncStatusService().load();
    if (mounted) setState(() => _status = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sincronización central')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.cloud_sync_outlined,
                size: 72, color: Color(0xFF1F4E78)),
            const SizedBox(height: 12),
            const Text('Firebase preparado',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'La estructura segura y la cola offline están listas. La conexión se activará al incorporar la configuración oficial del proyecto Firebase.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Card(
              color: const Color(0xFFFFF6DA),
              child: const ListTile(
                leading: Icon(Icons.info_outline, color: Color(0xFF9A6700)),
                title: Text('Configuración pendiente'),
                subtitle: Text('Falta incorporar google-services.json y habilitar Authentication, Firestore y Storage.'),
              ),
            ),
            const SizedBox(height: 14),
            if (_status == null)
              const Center(child: CircularProgressIndicator())
            else
              Row(children: [
                Expanded(child: _card('Pendientes', '${_status!.pending}',
                    Icons.schedule_outlined, const Color(0xFF1F4E78))),
                const SizedBox(width: 10),
                Expanded(child: _card('Con error', '${_status!.errors}',
                    Icons.error_outline, const Color(0xFFB42318))),
              ]),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Última sincronización correcta'),
                subtitle: Text(_status?.lastSuccess == null
                    ? 'Todavía no se realizó una sincronización.'
                    : _date(_status!.lastSuccess!)),
                trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Protecciones incorporadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Card(child: Column(children: [
              ListTile(leading: Icon(Icons.person_outline),
                  title: Text('Acceso individual'),
                  subtitle: Text('Cada trabajador solo podrá consultar y firmar sus asignaciones.')),
              Divider(height: 1),
              ListTile(leading: Icon(Icons.admin_panel_settings_outlined),
                  title: Text('Control administrativo'),
                  subtitle: Text('Solo el administrador podrá importar, cerrar y generar registros.')),
              Divider(height: 1),
              ListTile(leading: Icon(Icons.offline_bolt_outlined),
                  title: Text('Cola offline'),
                  subtitle: Text('Las acciones sin internet quedarán pendientes para envío posterior.')),
            ])),
          ],
        ),
      );

  Widget _card(String title, String value, IconData icon, Color color) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 26,
                fontWeight: FontWeight.w900, color: color)),
            Text(title),
          ]),
        ),
      );

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
