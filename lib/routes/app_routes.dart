import 'package:flutter/material.dart';

class AppRoutes {
  static const home = '/';
  static const personal = '/personal';
  static const capacitaciones = '/capacitaciones';
  static const inspecciones = '/inspecciones';
  static const reportes = '/reportes';

  static Map<String, WidgetBuilder> routes = {
    home: (_) => const Placeholder(),
    personal: (_) => const Placeholder(),
    capacitaciones: (_) => const Placeholder(),
    inspecciones: (_) => const Placeholder(),
    reportes: (_) => const Placeholder(),
  };
}
