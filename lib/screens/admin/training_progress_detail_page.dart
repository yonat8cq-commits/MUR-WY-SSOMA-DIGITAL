import 'package:flutter/material.dart';
import '../../services/admin_tracking_service.dart';
import '../../services/authorized_signature_service.dart';
import '../../services/document_control_service.dart';
import '../../services/company_service.dart';
import '../../services/pdf_service.dart';

enum ParticipantFilter { all, pending, signed }

class TrainingProgressDetailPage extends StatefulWidget {
  final TrainingProgress training;
  const TrainingProgressDetailPage({super.key, required this.training});

  @override
  State<TrainingProgressDetailPage> createState() =>
      _TrainingProgressDetailPageState();
}

class _TrainingProgressDetailPageState
    extends State<TrainingProgressDetailPage> {
  List<ParticipantProgress> _participants = [];
  ParticipantFilter _filter = ParticipantFilter.all;
  bool _loading = true;
  bool _exporting = false;
  List<AuthorizedSigner> _trainers = [];
  String? _trainerId;
  DocumentControl? _control;
  List<RecordVersion> _history = [];
  List<CompanyProfile> _companies = [];
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await AdminTrackingService().loadParticipants(
      widget.training.key,
    );
    final signatureService = AuthorizedSignatureService();
    final trainers = await signatureService.loadTrainers();
    final trainerId = await signatureService.trainerIdFor(widget.training.key);
    final documentService = DocumentControlService();
    final control = await documentService.load(
      widget.training.key,
      widget.training.date,
    );
    final history = await documentService.history(widget.training.key);
    final companyService = CompanyService();
    final companies = await companyService.loadCompanies();
    final companyId =
        await companyService.companyIdForTraining(widget.training.key);
    if (!mounted) return;
    setState(() {
      _participants = rows;
      _trainers = trainers;
      _trainerId = trainerId;
      _control = control;
      _history = history;
      _companies = companies;
      _companyId = companyId;
      _loading = false;
    });
  }

  Future<void> _assignCompany(String? companyId) async {
    if (companyId == null) return;
    await CompanyService().assignToTraining(widget.training.key, companyId);
    if (!mounted) return;
    setState(() => _companyId = companyId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Empresa asignada al registro.')),
    );
  }

  Future<void> _closeRecord() async {
    final pending = _participants.where((item) => !item.signed).length;
    if (pending > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aún existen $pending firmas pendientes.')),
      );
      return;
    }
    if (_trainerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona primero al capacitador.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_outline, size: 44),
        title: const Text('Cerrar registro'),
        content: const Text(
          'Se generará una versión definitiva y los trabajadores ya no '
          'podrán modificar sus firmas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CERRAR REGISTRO'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DocumentControlService().close(
      widget.training.key,
      widget.training.date,
    );
    await _load();
  }

  Future<void> _reopenRecord() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Corregir registro cerrado'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Motivo de la corrección',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('REABRIR'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    await DocumentControlService().reopen(
      widget.training.key,
      widget.training.date,
      reason,
    );
    await _load();
  }

  Future<void> _assignTrainer(String? trainerId) async {
    if (trainerId == null) return;
    await AuthorizedSignatureService().assignTrainer(
      widget.training.key,
      trainerId,
    );
    if (!mounted) return;
    setState(() => _trainerId = trainerId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Capacitador asignado al registro.')),
    );
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final path = await PdfService().saveFsgi(widget.training.key);
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registro guardado en: $path')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el registro: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _participants.where((participant) {
      if (_filter == ParticipantFilter.pending) return !participant.signed;
      if (_filter == ParticipantFilter.signed) return participant.signed;
      return true;
    }).toList();
    final signed = _participants.where((item) => item.signed).length;
    final pending = _participants.length - signed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de participantes'),
        actions: [
          IconButton(
            tooltip: 'Descargar F-SGI-04-01',
            onPressed: _loading || _exporting ? null : _exportPdf,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(widget.training.course,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(widget.training.date,
                    style: const TextStyle(color: Color(0xFF626B7A))),
                const SizedBox(height: 10),
                Chip(
                  avatar: Icon(
                    _control?.isClosed == true
                        ? Icons.lock_outline
                        : Icons.description_outlined,
                    size: 17,
                  ),
                  label: Text(
                    _control?.statusFor(
                          total: _participants.length,
                          signed: signed,
                        ) ??
                        'EN FIRMA',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: Text('Todos (' +
                          _participants.length.toString() +
                          ')'),
                      selected: _filter == ParticipantFilter.all,
                      onSelected: (_) =>
                          setState(() => _filter = ParticipantFilter.all),
                    ),
                    FilterChip(
                      label: Text('Pendientes (' + pending.toString() + ')'),
                      selected: _filter == ParticipantFilter.pending,
                      onSelected: (_) =>
                          setState(() => _filter = ParticipantFilter.pending),
                    ),
                    FilterChip(
                      label: Text('Firmados (' + signed.toString() + ')'),
                      selected: _filter == ParticipantFilter.signed,
                      onSelected: (_) =>
                          setState(() => _filter = ParticipantFilter.signed),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _companyId,
                  decoration: const InputDecoration(
                    labelText: 'Empresa del registro',
                    prefixIcon: Icon(Icons.business_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _companies
                      .map(
                        (company) => DropdownMenuItem(
                          value: company.id,
                          child: Text(company.businessName),
                        ),
                      )
                      .toList(),
                  onChanged: _control?.isClosed == true ? null : _assignCompany,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _trainerId,
                  decoration: const InputDecoration(
                    labelText: 'Capacitador del registro',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Selecciona a Roly o Karina'),
                  items: _trainers
                      .map(
                        (trainer) => DropdownMenuItem(
                          value: trainer.id,
                          child: Text(trainer.fullName),
                        ),
                      )
                      .toList(),
                  onChanged: _control?.isClosed == true ? null : _assignTrainer,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Responsable: CUTIPA QUISPE JHONATHAN - ASISTENTE SSOMA',
                  style: TextStyle(fontSize: 12, color: Color(0xFF626B7A)),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _exporting ? null : _exportPdf,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(
                    _exporting
                        ? 'Generando registro...'
                        : 'Descargar F-SGI-04-01',
                  ),
                ),
                const SizedBox(height: 8),
                if (_control?.isClosed == true)
                  OutlinedButton.icon(
                    onPressed: _reopenRecord,
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('REABRIR PARA CORRECCIÓN'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _closeRecord,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('CERRAR REGISTRO DEFINITIVO'),
                  ),
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Historial documental',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  ..._history.map(
                    (entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        entry.action == 'CIERRE'
                            ? Icons.lock_outline
                            : Icons.edit_note_outlined,
                      ),
                      title: Text('${entry.action} - Versión ${entry.version}'),
                      subtitle: Text(entry.reason),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ...visible.map(
                  (participant) => Card(
                    elevation: 0,
                    color: Colors.white,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: participant.signed
                            ? const Color(0xFFE4F5EA)
                            : const Color(0xFFFFF2CC),
                        child: Icon(
                          participant.signed ? Icons.check : Icons.schedule,
                          color: participant.signed
                              ? const Color(0xFF16743B)
                              : const Color(0xFF9A5D00),
                        ),
                      ),
                      title: Text(participant.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        participant.dni +
                            (participant.position.isEmpty
                                ? ''
                                : ' • ' + participant.position),
                      ),
                      trailing:
                          Text(participant.signed ? 'Firmado' : 'Pendiente'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
