import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/excel_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  TecsupImportResult? _result;

  void _loadReferenceImport() {
    setState(() => _result = TecsupImportResult.referencePreview());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vista de validación TECSUP cargada correctamente.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Panel administrador', style: TextStyle(fontSize: 17)),
            Text('Jhonathan Cutipa • Super administrador',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (_) => false,
            ),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Importación de capacitaciones',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'El sistema acepta exclusivamente el estado exacto APROBADO.',
            style: TextStyle(color: Color(0xFF626B7A)),
          ),
          const SizedBox(height: 18),
          Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.table_view_outlined,
                          color: Color(0xFF16743B), size: 34),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Excel TECSUP',
                          style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Valida la hoja “lista”, detecta columnas por nombre, '
                    'excluye desaprobados y separa cada curso, fecha, '
                    'programación y grupo.',
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _loadReferenceImport,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('PROBAR ARCHIVO TECSUP ANALIZADO'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La selección de archivos externos se conectará en la '
                    'versión Windows sin alterar la APK del trabajador.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF626B7A)),
                  ),
                ],
              ),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metric('Filas', result.totalRows.toString(), Colors.blue),
                _metric(
                    'Aprobados', result.approvedRows.toString(), Colors.green),
                _metric(
                    'Excluidos', result.excludedRows.toString(), Colors.orange),
                _metric('Trabajadores', result.uniqueWorkers.toString(),
                    Colors.purple),
              ],
            ),
            const SizedBox(height: 22),
            const Text('Resultado de validación',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Colors.white,
              child: Column(
                children: result.trainings
                    .map(
                      (training) => ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.school_outlined),
                        ),
                        title: Text(training.course,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(training.date),
                        trailing: Text(
                          training.approvedParticipants.toString(),
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: const Color(0xFFFFF5D6),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Observaciones para revisión',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      ...result.warnings.map(
                        (warning) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• ' + warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value, MaterialColor color) => SizedBox(
        width: 155,
        child: Card(
          elevation: 0,
          color: color.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: color.shade800)),
                Text(label),
              ],
            ),
          ),
        ),
      );
}
