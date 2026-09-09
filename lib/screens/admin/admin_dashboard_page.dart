import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../routes/app_routes.dart';
import '../../services/excel_service.dart';
import '../../services/import_persistence_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  TecsupImportResult? _result;
  String? _selectedFileName;
  bool _loading = false;
  bool _saving = false;
  ImportSaveSummary? _saveSummary;

  Future<void> _selectAndProcessExcel() async {
    const typeGroup = XTypeGroup(
      label: 'Archivos Excel',
      extensions: ['xlsx'],
      mimeTypes: [
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    setState(() => _loading = true);
    try {
      final bytes = await file.readAsBytes();
      final result = ExcelService().importTecsup(bytes);
      if (!mounted) return;
      setState(() {
        _result = result;
        _selectedFileName = file.name;
        _saveSummary = null;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel procesado correctamente.')),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('No se pudo leer el archivo. Verifica que sea un Excel .xlsx válido.');
    }
  }

  Future<void> _saveImport() async {
    final result = _result;
    final fileName = _selectedFileName;
    if (result == null || fileName == null) return;
    setState(() => _saving = true);
    try {
      final summary = await ImportPersistenceService().save(result, fileName);
      if (!mounted) return;
      setState(() {
        _saveSummary = summary;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Importación guardada y cuentas preparadas.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('No se pudo guardar la importación en este dispositivo.');
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 46),
        title: const Text('Archivo no válido'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          ),
        ],
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
            tooltip: 'Seguimiento de firmas',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.signatureTracking),
            icon: const Icon(Icons.analytics_outlined),
          ),
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
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.signatureTracking),
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('VER SEGUIMIENTO DE FIRMAS'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.authorizedSignatures),
            icon: const Icon(Icons.draw_outlined),
            label: const Text('CONFIGURAR FIRMAS AUTORIZADAS'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.workersAdmin),
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text('ADMINISTRAR TRABAJADORES Y ACCESOS'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.companiesAdmin),
            icon: const Icon(Icons.business_outlined),
            label: const Text('CONFIGURAR EMPRESAS Y LOGOS'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.consentsAdmin),
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('REVISAR CONSENTIMIENTOS'),
          ),
          const SizedBox(height: 12),
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
                    onPressed: _loading ? null : _selectAndProcessExcel,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(
                      _loading ? 'PROCESANDO…' : 'SELECCIONAR EXCEL TECSUP',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedFileName == null
                        ? 'Selecciona un archivo .xlsx. Los datos se procesan '
                            'localmente y no se cargan a GitHub.'
                        : 'Archivo: ' + _selectedFileName!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF626B7A)),
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
            const SizedBox(height: 18),
            if (_saveSummary == null)
              ElevatedButton.icon(
                onPressed: _saving ? null : _saveImport,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_alt_outlined),
                label: Text(
                  _saving
                      ? 'GUARDANDO…'
                      : 'CONFIRMAR IMPORTACIÓN Y CREAR CUENTAS',
                ),
              )
            else
              Card(
                elevation: 0,
                color: const Color(0xFFE4F5EA),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Icon(Icons.verified,
                          color: Color(0xFF16743B), size: 46),
                      const SizedBox(height: 8),
                      const Text(
                        'Importación guardada',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _saveSummary!.workers.toString() +
                            ' trabajadores • ' +
                            _saveSummary!.trainings.toString() +
                            ' capacitaciones • ' +
                            _saveSummary!.assignments.toString() +
                            ' asignaciones',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Las cuentas quedan en estado TEMPORAL y deberán '
                        'cambiar contraseña en el primer acceso.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF3D6248)),
                      ),
                    ],
                  ),
                ),
              ),
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
