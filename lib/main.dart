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
      body: const Center(
        child: Text(
          'Sistema SSOMA listo para desarrollo',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
