import 'package:flutter/material.dart';
import '../screens/login/login_page.dart';
import '../screens/worker/worker_home_page.dart';
import '../screens/admin/admin_dashboard_page.dart';
import '../screens/admin/signature_tracking_page.dart';
import '../screens/admin/authorized_signatures_page.dart';

class AppRoutes {
  static const login = '/';
  static const workerHome = '/trabajador';
  static const adminHome = '/administrador';
  static const signatureTracking = '/administrador/seguimiento';
  static const authorizedSignatures = '/administrador/firmas-autorizadas';

  static final Map<String, WidgetBuilder> routes = {
    login: (_) => const LoginPage(),
    workerHome: (_) => const WorkerHomePage(),
    adminHome: (_) => const AdminDashboardPage(),
    signatureTracking: (_) => const SignatureTrackingPage(),
    authorizedSignatures: (_) => const AuthorizedSignaturesPage(),
  };
}
