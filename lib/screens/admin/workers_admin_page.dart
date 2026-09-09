import 'package:flutter/material.dart';

import '../../services/worker_admin_service.dart';

class WorkersAdminPage extends StatefulWidget {
  const WorkersAdminPage({super.key});

  @override
  State<WorkersAdminPage> createState() => _WorkersAdminPageState();
}

class _WorkersAdminPageState extends State<WorkersAdminPage> {
  final _service = WorkerAdminService();
  final _search = TextEditingController();
  List<WorkerAdminItem> _workers = [];
  bool _loading = true;

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
    final workers = await _service.loadWorkers();
    if (!mounted) return;
    setState(() {
      _workers = workers;
      _loading = false;
    });
  }

  Future<void> _setActive(WorkerAdminItem worker, bool active) async {
    await _service.setActive(worker.dni, active);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          active ? 'Cuenta activada.' : 'Cuenta desactivada sin borrar historial.',
        ),
      ),
    );
  }

  Future<void> _resetPassword(WorkerAdminItem worker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.password_outlined, size: 44),
        title: const Text('Restablecer acceso'),
        content: Text(
          '${worker.fullName} deberá ingresar con la contraseña temporal '
          '${WorkerAdminService.temporaryPassword} y crear una nueva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESTABLECER'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.resetTemporaryPassword(worker.dni);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _workers.where((worker) {
      return worker.dni.contains(query) ||
          worker.fullName.toLowerCase().contains(query) ||
          worker.company.toLowerCase().contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar trabajadores'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  '${_workers.length} trabajadores registrados',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Desactivar una cuenta no elimina sus cursos, consentimientos '
                  'ni firmas históricas.',
                  style: TextStyle(color: Color(0xFF626B7A)),
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
                const SizedBox(height: 16),
                ...visible.map(
                  (worker) => Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: worker.active
                            ? const Color(0xFFE4F5EA)
                            : const Color(0xFFFFE1E1),
                        child: Icon(
                          worker.active ? Icons.person : Icons.person_off,
                        ),
                      ),
                      title: Text(
                        worker.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${worker.dni} • ${worker.position}'),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${worker.company} • ${worker.area}'),
                          subtitle: Text(
                            'Cursos: ${worker.trainings} • Firmados: ${worker.signed}\n'
                            'Acceso: ${worker.requiresPasswordChange ? 'TEMPORAL' : worker.accountStatus}',
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: worker.active,
                          onChanged: (value) => _setActive(worker, value),
                          title: const Text('Cuenta activa'),
                        ),
                        OutlinedButton.icon(
                          onPressed: worker.active
                              ? () => _resetPassword(worker)
                              : null,
                          icon: const Icon(Icons.password_outlined),
                          label: const Text('RESTABLECER CONTRASEÑA'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
