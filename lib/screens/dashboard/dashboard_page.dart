import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel SSOMA')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        children: const [
          Card(child: Center(child: Text('Personal'))),
          Card(child: Center(child: Text('Capacitaciones'))),
          Card(child: Center(child: Text('Inspecciones'))),
          Card(child: Center(child: Text('Reportes'))),
        ],
      ),
    );
  }
}
