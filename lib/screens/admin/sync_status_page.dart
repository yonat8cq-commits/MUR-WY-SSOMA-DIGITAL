import 'package:flutter/material.dart';

import '../../services/firebase_bootstrap_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/sync_status_service.dart';

class SyncStatusPage extends StatefulWidget {
  const SyncStatusPage({super.key});

  @override
  State<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends State<SyncStatusPage> {
  SyncStatus? _status;

  FirebaseBootstrapService get _firebase => FirebaseBootstrapService.instance;

  @override
  void initState() {
    super.initState();
    _firebase.addListener(_firebaseChanged);
    _load();
  }

  @override
  void dispose() {
    _firebase.removeListener(_firebaseChanged);
    super.dispose();
  }

  void _firebaseChanged() {
    if (mounted) setState(() {});
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
            Text(_firebase.isReady ? 'Firebase conectado' : 'Firebase sin conexión',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              _firebase.isReady
                  ? 'La aplicación reconoce el proyecto mur-wy-ssoma-digital. Las acciones offline permanecen protegidas hasta que se habiliten el acceso y los servicios centrales.'
                  : 'La aplicación continuará trabajando de forma local y conservará las acciones pendientes para enviarlas cuando Firebase esté disponible.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Card(
              color: _firebase.isReady
                  ? const Color(0xFFE7F6EC)
                  : const Color(0xFFFFF6DA),
              child: ListTile(
                leading: Icon(
                  _firebase.isReady ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  color: _firebase.isReady ? const Color(0xFF18753C) : const Color(0xFF9A6700),
                ),
                title: Text(_firebase.isReady
                    ? 'Configuración Android instalada'
                    : 'Modo local activo'),
                subtitle: Text(_firebase.isReady
                    ? 'Siguiente: habilitar Authentication, Firestore y Storage en Firebase Console.'
                    : 'No se perderán firmas ni confirmaciones por falta de internet.'),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: Icon(
                  FirebaseAuthService.instance.hasCentralSession
                      ? Icons.verified_user_outlined
                      : Icons.person_off_outlined,
                ),
                title: Text(FirebaseAuthService.instance.hasCentralSession
                    ? 'Usuario central autenticado'
                    : 'Sin sesión central'),
                subtitle: const Text(
                  'El acceso por DNI utiliza una identidad interna y no expone el correo personal del trabajador.',
                ),
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
