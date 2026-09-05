import 'package:flutter/material.dart';

class ModulePage extends StatelessWidget {
  final String title;
  const ModulePage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}
