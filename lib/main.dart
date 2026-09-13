import 'package:flutter/material.dart';
import 'routes/app_routes.dart';

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
      initialRoute: AppRoutes.home,
      routes: AppRoutes.routes,
    );
  }
}
