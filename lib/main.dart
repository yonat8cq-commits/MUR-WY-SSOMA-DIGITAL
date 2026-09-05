import 'package:flutter/material.dart';

void main() {
  runApp(const MurWySsomaApp());
}

class MurWySsomaApp extends StatelessWidget {
  const MurWySsomaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MUR WY SSOMA DIGITAL',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MUR WY SSOMA DIGITAL'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _moduleCard('Personal Activo', Icons.people),
            _moduleCard('Capacitaciones', Icons.school),
            _moduleCard('Inspecciones F-SGI-04-01', Icons.assignment),
            _moduleCard('Reportes PDF / Excel', Icons.picture_as_pdf),
          ],
        ),
      ),
    );
  }

  Widget _moduleCard(String title, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios),
      ),
    );
  }
}
