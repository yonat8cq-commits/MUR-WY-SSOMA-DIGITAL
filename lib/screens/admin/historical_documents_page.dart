import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../services/historical_document_service.dart';

class HistoricalDocumentsPage extends StatefulWidget {
  const HistoricalDocumentsPage({super.key});

  @override
  State<HistoricalDocumentsPage> createState() => _HistoricalDocumentsPageState();
}

class _HistoricalDocumentsPageState extends State<HistoricalDocumentsPage> {
  final _service = HistoricalDocumentService();
  final _search = TextEditingController();
  List<HistoricalDocument> _documents = [];
  bool _loading = true;
  bool _importing = false;

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
    final documents = await _service.loadDocuments();
    if (!mounted) return;
    setState(() {
      _documents = documents;
      _loading = false;
    });
  }

  Future<void> _startImport() async {
    final file = await _service.selectFile();
    if (file == null || !mounted) return;
    final data = await _requestMetadata(file);
    if (data == null) return;
    setState(() => _importing = true);
    try {
      await _service.importDocument(
        file: file,
        title: data.title,
        course: data.course,
        trainingDate: data.date,
        company: data.company,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capacitación histórica archivada correctamente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo importar: $error')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<_HistoricalMetadata?> _requestMetadata(XFile file) async {
    final title = TextEditingController(text: file.name);
    final course = TextEditingController();
    final date = TextEditingController();
    final company = TextEditingController(text: 'MUR WY S.A.C.');
    final result = await showDialog<_HistoricalMetadata>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Datos del documento histórico'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(file.name, style: const TextStyle(color: Color(0xFF626B7A))),
              const SizedBox(height: 14),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Título del archivo')),
              const SizedBox(height: 10),
              TextField(controller: course, decoration: const InputDecoration(labelText: 'Curso *')),
              const SizedBox(height: 10),
              TextField(
                controller: date,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Fecha de capacitación *', suffixIcon: Icon(Icons.calendar_month)),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    initialDate: DateTime.now(),
                  );
                  if (selected != null) {
                    date.text = '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(controller: company, decoration: const InputDecoration(labelText: 'Empresa *')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          FilledButton(
            onPressed: () {
              if (course.text.trim().isEmpty || date.text.isEmpty || company.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa curso, fecha y empresa.')));
                return;
              }
              Navigator.pop(context, _HistoricalMetadata(title.text, course.text, date.text, company.text));
            },
            child: const Text('ARCHIVAR'),
          ),
        ],
      ),
    );
    title.dispose();
    course.dispose();
    date.dispose();
    company.dispose();
    return result;
  }

  Future<void> _download(HistoricalDocument document) async {
    final path = await _service.saveCopy(document);
    if (!mounted || path == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copia guardada en $path')));
  }

  Future<void> _delete(HistoricalDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar documento histórico'),
        content: Text('Se eliminará “${document.title}”. Esta acción no afecta trabajadores ni capacitaciones actuales.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ELIMINAR')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteDocument(document.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _documents.where((document) =>
        document.title.toLowerCase().contains(query) ||
        document.course.toLowerCase().contains(query) ||
        document.company.toLowerCase().contains(query) ||
        document.trainingDate.contains(query)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Archivo histórico')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _startImport,
        icon: _importing
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.upload_file),
        label: Text(_importing ? 'IMPORTANDO…' : 'IMPORTAR ARCHIVO'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 92),
              children: [
                Text('${_documents.length} documentos históricos', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                  'Archiva registros anteriores en PDF, Excel, Word o imagen sin mezclarlos con las capacitaciones activas.',
                  style: TextStyle(color: Color(0xFF626B7A)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Buscar por curso, empresa o fecha', prefixIcon: Icon(Icons.search)),
                ),
                const SizedBox(height: 16),
                if (visible.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No hay documentos históricos para mostrar.'))),
                ...visible.map((document) => Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
                        title: Text(document.course, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${document.trainingDate} • ${document.company}\n${document.fileName} • ${_fileSize(document.fileSize)}'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => value == 'download' ? _download(document) : _delete(document),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'download', child: Text('Descargar copia')),
                            PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
    );
  }

  String _fileSize(int bytes) {
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
}

class _HistoricalMetadata {
  final String title;
  final String course;
  final String date;
  final String company;

  const _HistoricalMetadata(this.title, this.course, this.date, this.company);
}
