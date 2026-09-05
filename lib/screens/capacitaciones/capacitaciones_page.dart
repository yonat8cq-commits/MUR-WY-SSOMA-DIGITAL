import 'package:flutter/material.dart';

class CapacitacionesPage extends StatelessWidget {
  const CapacitacionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capacitaciones')),
      body: const Center(
        child: Text('Registro de cursos y participantes'),
      ),
    );
  }
}
