import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../routes/app_routes.dart';
import '../../services/excel_service.dart';
import '../../services/import_persistence_service.dart';
import '../../services/notification_service.dart';
import '../../services/reminder_service.dart';
import '../../services/admin_auth_service.dart';
import '../../services/executive_dashboard_service.dart';

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
  bool _checkingAccess = true;
  ExecutiveSummary? _summary;
  bool _loadingSummary = false;

  @override
  void initState() {
    super.initState();
    _verifyAccess();
  }

  Future<void> _verifyAccess() async {
    if (!AdminAuthService().sessionAuthorized) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.adminAuth,
        (route) => route.settings.name == AppRoutes.login,
      );
      return;
    }
    setState(() => _checkingAccess = false);
    await _loadSummary();
    await _showAndroidReminders();
  }

  Future<void> _loadSummary() async {
    if (mounted) setState(() => _loadingSummary = true);
    final summary = await ExecutiveDashboardService().load();
    if (mounted) {
      setState(() {
        _summary = summary;
        _loadingSummary = false;
      });
    }
  }

  void _logout() {
    AdminAuthService().logout();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (_) => false,
    );
  }

  Future<void> _showAndroidReminders() async {
    final alerts = await ReminderService().loadAlerts();
    await NotificationService.instance.showAdminReminder(alerts);
  }

  Future<void> _selectAndProcessExcel() async {
    setState(() {
      _result = null;
      _selectedFileName = null;
      _saveSummary = null;
    });
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
        const SnackBar(
          content: Text(
            'Excel nuevo procesado. Al guardar reemplazará la campaña visible y actualizará las estadísticas.',
          ),
        ),
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
      await _loadSummary();
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
    if (_checkingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Resumen ejecutivo SSOMA',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                tooltip: 'Actualizar indicadores',
                onPressed: _loadingSummary ? null : _loadSummary,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Indicadores actualizados con la información guardada en este dispositivo.',
            style: TextStyle(color: Color(0xFF626B7A)),
          ),
          const SizedBox(height: 14),
          if (_loadingSummary && _summary == null)
            const Center(child: CircularProgressIndicator())
          else if (_summary != null)
            _executivePanel(_summary!),
          const SizedBox(height: 26),
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
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.historicalDocuments),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('ARCHIVO DE CAPACITACIONES HISTÓRICAS'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.reminders),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('VER ALERTAS Y RECORDATORIOS'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.auditLog),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('VER REGISTRO DE AUDITORÍA'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.backup),
            icon: const Icon(Icons.backup_outlined),
            label: const Text('COPIAS DE SEGURIDAD Y RESTAURACIÓN'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.adminSecurity),
            icon: const Icon(Icons.security_outlined),
            label: const Text('SEGURIDAD DE LA CUENTA'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.syncStatus),
            icon: const Icon(Icons.cloud_sync_outlined),
            label: const Text('SINCRONIZACIÓN CENTRAL FIREBASE'),
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

  Widget _executivePanel(ExecutiveSummary summary) {
    final percentage = (summary.signatureProgress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: const Color(0xFFEAF6EE),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(Icons.draw_outlined, color: Color(0xFF16743B)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Avance general de firmas',
                      style: TextStyle(fontWeight: FontWeight.w700))),
                  Text('$percentage%', style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: summary.signatureProgress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 8),
                Text('${summary.signed} firmas realizadas • ${summary.pending} pendientes'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth >= 700
              ? (constraints.maxWidth - 24) / 4
              : (constraints.maxWidth - 8) / 2;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            _executiveMetric('Trabajadores', '${summary.workers}',
                '${summary.activeWorkers} activos', Icons.groups_outlined,
                const Color(0xFF1F4E78), width),
            _executiveMetric('Capacitaciones', '${summary.trainings}',
                '${summary.completed} completas', Icons.school_outlined,
                const Color(0xFF5B3F8C), width),
            _executiveMetric('Vencidas', '${summary.expired}',
                'Con firmas pendientes', Icons.warning_amber_rounded,
                const Color(0xFFB45309), width),
            _executiveMetric('Cerradas', '${summary.closed}',
                'Control documental', Icons.task_alt_outlined,
                const Color(0xFF16743B), width),
          ]);
        }),
      ],
    );
  }

  Widget _executiveMetric(String title, String value, String subtitle,
      IconData icon, Color color, double width) => SizedBox(
        width: width,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 25,
                  fontWeight: FontWeight.w900, color: color)),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(
                  fontSize: 11, color: Color(0xFF626B7A))),
            ]),
          ),
        ),
      );

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
