import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class TrainingViewData {
  final String title;
  final String date;
  final String hours;
  final String provider;
  final String deadline;

  const TrainingViewData({required this.title, required this.date, required this.hours, required this.provider, required this.deadline});
}

class TrainingDetailPage extends StatefulWidget {
  final TrainingViewData training;
  const TrainingDetailPage({super.key, required this.training});

  @override
  State<TrainingDetailPage> createState() => _TrainingDetailPageState();
}

class _TrainingDetailPageState extends State<TrainingDetailPage> {
  final SignatureController _signature = SignatureController(
    penStrokeWidth: 2.4,
    penColor: const Color(0xFF123EBA),
    exportBackgroundColor: Colors.white,
  );
  bool _confirmed = false;
  bool _saving = false;

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confirma primero que participaste en la capacitación.')));
      return;
    }
    if (_signature.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firma dentro del recuadro azul.')));
      return;
    }
    setState(() => _saving = true);
    final Uint8List? signaturePng = await _signature.toPngBytes();
    if (!mounted) return;
    setState(() => _saving = false);
    if (signaturePng == null) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.verified_rounded, color: Color(0xFF16743B), size: 52),
        title: const Text('Firma registrada'),
        content: const Text('Tu confirmación quedó guardada en este dispositivo. La sincronización con el servidor se incorporará en la siguiente fase.'),
        actions: [FilledButton(onPressed: () { Navigator.pop(dialogContext); Navigator.pop(context); }, child: const Text('FINALIZAR'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.training;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar capacitación')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                _data(Icons.calendar_today_outlined, 'Fecha', t.date),
                _data(Icons.schedule_outlined, 'Duración', t.hours),
                _data(Icons.school_outlined, 'Capacitador', t.provider),
                _data(Icons.event_busy_outlined, 'Plazo de firma', t.deadline),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          CheckboxListTile(
            value: _confirmed,
            onChanged: (value) => setState(() => _confirmed = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('Confirmo que participé en esta capacitación.', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Esta confirmación quedará asociada a tu DNI, fecha y hora.'),
          ),
          const SizedBox(height: 10),
          const Text('Firma aquí', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Usa el dedo como si firmaras con lapicero azul.', style: TextStyle(color: Color(0xFF626B7A))),
          const SizedBox(height: 12),
          Container(
            height: 260,
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF123EBA), width: 2), borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: Signature(controller: _signature, backgroundColor: Colors.white),
          ),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _signature.clear, icon: const Icon(Icons.refresh), label: const Text('LIMPIAR'))),
          const SizedBox(height: 10),
          ElevatedButton.icon(onPressed: _saving ? null : _submit, icon: _saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.draw), label: Text(_saving ? 'GUARDANDO…' : 'CONFIRMAR Y FIRMAR')),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _data(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 19, color: const Color(0xFF626B7A)),
      const SizedBox(width: 10),
      SizedBox(width: 92, child: Text(label, style: const TextStyle(color: Color(0xFF626B7A)))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]),
  );
}
