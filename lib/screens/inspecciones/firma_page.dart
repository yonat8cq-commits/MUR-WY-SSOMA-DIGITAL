import 'package:flutter/material.dart';

class FirmaPage extends StatelessWidget {
  const FirmaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firma digital')),
      body: const Center(
        child: Text('Área preparada para captura de firma'),
      ),
    );
  }
}
