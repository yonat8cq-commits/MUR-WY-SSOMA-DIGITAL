import 'package:flutter/material.dart';
import '../screens/module_page.dart';

class AppRoutes {
  static const home = '/';
  static const personal = '/personal';
  static const capacitaciones = '/capacitaciones';
  static const inspecciones = '/inspecciones';
  static const reportes = '/reportes';

  static Map<String, WidgetBuilder> routes = {
    home: (_) => const ModulePage(title: 'MUR WY SSOMA DIGITAL'),
    personal: (_) => const ModulePage(title: 'Personal Activo'),
    capacitaciones: (_) => const ModulePage(title: 'Capacitaciones'),
    inspecciones: (_) => const ModulePage(title: 'Inspecciones F-SGI-04-01'),
    reportes: (_) => const ModulePage(title: 'Reportes PDF / Excel'),
  };
}
