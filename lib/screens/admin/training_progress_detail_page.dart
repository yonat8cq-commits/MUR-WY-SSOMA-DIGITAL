import 'package:flutter/material.dart';
import '../../services/admin_tracking_service.dart';
import '../../services/authorized_signature_service.dart';
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
    if (!mounted) return;
    setState(() {
      _participants = rows;
      _trainers = trainers;
      _trainerId = trainerId;
      _loading = false;
    });
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
                  onChanged: _assignTrainer,
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
