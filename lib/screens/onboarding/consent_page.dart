import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../../routes/app_routes.dart';
import '../../services/offline_workflow_service.dart';

class ConsentPage extends StatefulWidget {
  final String dni;
  const ConsentPage({super.key, required this.dni});

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  final SignatureController _signature = SignatureController(
    penStrokeWidth: 2.4,
    penColor: const Color(0xFF123EBA),
    exportBackgroundColor: Colors.white,
  );
  bool _accepted = false;
  bool _saving = false;

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_accepted) {
      _message('Debes aceptar la autorización para continuar.');
      return;
    }
    if (_signature.isEmpty) {
      _message('Registra tu firma en el recuadro azul.');
      return;
    }
    setState(() => _saving = true);
    final Uint8List? png = await _signature.toPngBytes();
    if (png == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    await OfflineWorkflowService.instance.saveConsent(widget.dni, png);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.workerHome,
      (_) => false,
    );
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autorización de firma'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Autorización de uso de firma electrónica para registros SSOMA',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'DNI: ' + widget.dni + '  •  Versión 1.0',
            style: const TextStyle(color: Color(0xFF626B7A)),
          ),
          const SizedBox(height: 16),
          const Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Autorizo a MUR WY S.A.C. a registrar y utilizar mi firma electrónica '
                'exclusivamente como evidencia de participación en inducciones y '
                'capacitaciones SSOMA. Cada uso requerirá mi confirmación. La evidencia '
                'conservará mi DNI, fecha, hora y versión del consentimiento. Puedo '
                'solicitar información sobre el tratamiento de mis datos al responsable '
                'SSOMA. Esta autorización no permite utilizar mi firma para documentos '
                'distintos a los registros expresamente confirmados por mí.',
                style: TextStyle(height: 1.5),
              ),
            ),
          ),
          CheckboxListTile(
            value: _accepted,
            onChanged: (value) => setState(() => _accepted = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'He leído y acepto la autorización.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Firma de autorización',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Firma con el dedo como si utilizaras un lapicero azul.',
            style: TextStyle(color: Color(0xFF626B7A)),
          ),
          const SizedBox(height: 12),
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF123EBA), width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: Signature(controller: _signature, backgroundColor: Colors.white),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _signature.clear,
              icon: const Icon(Icons.refresh),
              label: const Text('LIMPIAR'),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _saving ? null : _finish,
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(_saving ? 'GUARDANDO…' : 'ACEPTAR Y CONTINUAR'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
