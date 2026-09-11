import 'package:flutter/material.dart';

import '../../services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final _service = BackupService();
  bool _working = false;

  Future<void> _create() async {
    setState(() => _working = true);
    try {
      final path = await _service.createBackup();
      if (mounted && path != null) _message('Copia de seguridad guardada correctamente.');
    } catch (_) {
      if (mounted) _message('No se pudo generar la copia de seguridad.', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _working = true);
    try {
      final summary = await _service.inspectBackup();
      if (!mounted || summary == null) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 46),
          title: const Text('Confirmar restauración'),
          content: Text(
            'Respaldo del ${_date(summary.createdAt)}\n'
            '${summary.tables} tablas • ${summary.records} registros\n\n'
            'Los datos actuales serán reemplazados. La contraseña y el código de recuperación del administrador se conservarán.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('RESTAURAR')),
          ],
        ),
      );
      if (confirmed == true) {
        await _service.restoreInspectedBackup();
        if (mounted) _message('Información restaurada correctamente.');
      }
    } on FormatException catch (error) {
      if (mounted) _message(error.message, error: true);
    } catch (_) {
      if (mounted) _message('No se pudo restaurar el respaldo.', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value),
      backgroundColor: error ? Colors.red.shade700 : null,
    ));
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Copias de seguridad')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Icon(Icons.cloud_done_outlined, size: 70, color: Color(0xFF16743B)),
            const SizedBox(height: 12),
            const Text(
              'Protección de la información',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Guarda periódicamente el archivo en un lugar seguro. Contiene datos personales, documentos y firmas electrónicas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.save_alt_outlined, size: 34),
                    title: Text('Generar respaldo completo', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('Crea un archivo .murwy para conservar fuera del dispositivo.'),
                  ),
                  FilledButton.icon(
                    onPressed: _working ? null : _create,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('GENERAR COPIA DE SEGURIDAD'),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.settings_backup_restore, size: 34),
                    title: Text('Restaurar información', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('Valida el archivo y solicita confirmación antes de reemplazar datos.'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _restore,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('SELECCIONAR Y RESTAURAR'),
                  ),
                ]),
              ),
            ),
            if (_working) ...[
              const SizedBox(height: 22),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      );
}
