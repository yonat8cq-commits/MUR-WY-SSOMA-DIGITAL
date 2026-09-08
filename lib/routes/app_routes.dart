import 'package:flutter/material.dart';
import '../screens/login/login_page.dart';
import '../screens/worker/worker_home_page.dart';

class AppRoutes {
  static const login = '/';
  static const workerHome = '/trabajador';

  static final Map<String, WidgetBuilder> routes = {
    login: (_) => const LoginPage(),
    workerHome: (_) => const WorkerHomePage(),
  };
}
