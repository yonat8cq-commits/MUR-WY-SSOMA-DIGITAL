import 'package:flutter/material.dart';
import '../screens/module_page.dart';
import '../screens/capacitaciones/capacitaciones_page.dart';
import '../screens/inspecciones/inspecciones_page.dart';
import '../screens/personal/personal_page.dart';

class AppRoutes {
  static const home = '/';
  static const personal = '/personal';
  static const capacitaciones = '/capacitaciones';
  static const inspecciones = '/inspecciones';
  static const reportes = '/reportes';

  static Map<String, WidgetBuilder> routes = {
    home: (_) => const ModulePage(title: 'MUR WY SSOMA DIGITAL'),
    personal: (_) => const PersonalPage(),
    capacitaciones: (_) => const CapacitacionesPage(),
    inspecciones: (_) => const InspeccionesPage(),
    reportes: (_) => const ModulePage(title: 'Reportes PDF / Excel'),
  };
}
