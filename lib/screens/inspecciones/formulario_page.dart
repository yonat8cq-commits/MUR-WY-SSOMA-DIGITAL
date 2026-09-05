import 'package:flutter/material.dart';

class FormularioInspeccionPage extends StatelessWidget {
  const FormularioInspeccionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Formulario F-SGI-04-01')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: 'Área')),
            TextField(decoration: InputDecoration(labelText: 'Condición encontrada')),
            TextField(decoration: InputDecoration(labelText: 'Acción correctiva')),
          ],
        ),
      ),
    );
  }
}
