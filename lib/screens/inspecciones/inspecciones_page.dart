import 'package:flutter/material.dart';

class InspeccionesPage extends StatelessWidget {
  const InspeccionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inspecciones SSOMA')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(child: ListTile(title: Text('F-SGI-04-01 Inspección'))),
          Card(child: ListTile(title: Text('Inspecciones programadas'))),
          Card(child: ListTile(title: Text('Evidencias fotográficas'))),
        ],
      ),
    );
  }
}
