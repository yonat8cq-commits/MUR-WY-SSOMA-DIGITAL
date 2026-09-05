import 'package:flutter/material.dart';

class PersonalPage extends StatelessWidget {
  const PersonalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Activo')),
      body: const Center(
        child: Text('Registro de trabajadores SSOMA'),
      ),
    );
  }
}
