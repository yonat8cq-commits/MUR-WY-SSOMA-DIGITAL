import 'package:flutter/material.dart';
import '../../services/admin_tracking_service.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows =
        await AdminTrackingService().loadParticipants(widget.training.key);
    if (!mounted) return;
    setState(() {
      _participants = rows;
      _loading = false;
    });
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
      appBar: AppBar(title: const Text('Detalle de participantes')),
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
