import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../services/authorized_signature_service.dart';

class AuthorizedSignaturesPage extends StatefulWidget {
  const AuthorizedSignaturesPage({super.key});

  @override
  State<AuthorizedSignaturesPage> createState() =>
      _AuthorizedSignaturesPageState();
}

class _AuthorizedSignaturesPageState extends State<AuthorizedSignaturesPage> {
  final _service = AuthorizedSignatureService();
  List<AuthorizedSigner> _signers = [];
  String? _savingId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final signers = await _service.loadSigners();
    if (!mounted) return;
    setState(() {
      _signers = signers;
      _loading = false;
      _savingId = null;
    });
  }

  Future<void> _selectSignature(AuthorizedSigner signer) async {
    const images = XTypeGroup(
      label: 'Imagen de firma',
      extensions: ['png', 'jpg', 'jpeg'],
      mimeTypes: ['image/png', 'image/jpeg'],
    );
    final file = await openFile(acceptedTypeGroups: const [images]);
    if (file == null) return;
    setState(() => _savingId = signer.id);
    try {
      final bytes = await file.readAsBytes();
      await _service.saveSignature(signer.id, bytes);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firma de ${signer.fullName} guardada.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la firma: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firmas autorizadas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text(
                  'Firmas listas para usar',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Roly y Karina se aplican automáticamente al elegir al '
                  'capacitador. Jhonathan aparece como responsable del registro. '
                  'Puedes reemplazar cualquier firma con una imagen nueva.',
                  style: TextStyle(color: Color(0xFF626B7A)),
                ),
                const SizedBox(height: 16),
                ..._signers.map(
                  (signer) => Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            signer.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text('${signer.position} • ${signer.role}'),
                          const SizedBox(height: 12),
                          Container(
                            height: 100,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD8DCE2)),
                            ),
                            child: signer.signaturePng == null
                                ? const Text('FIRMA NO CARGADA')
                                : Image.memory(
                                    signer.signaturePng!,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _savingId == signer.id
                                ? null
                                : () => _selectSignature(signer),
                            icon: const Icon(Icons.upload_file_outlined),
                            label: Text(
                              signer.signaturePng == null
                                  ? 'CARGAR FIRMA'
                                  : 'REEMPLAZAR FIRMA',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
