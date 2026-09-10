import 'dart:async';

import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/admin_auth_service.dart';
import '../../services/audit_service.dart';

class AdminSessionGuard extends StatefulWidget {
  final Widget child;

  const AdminSessionGuard({super.key, required this.child});

  @override
  State<AdminSessionGuard> createState() => _AdminSessionGuardState();
}

class _AdminSessionGuardState extends State<AdminSessionGuard>
    with WidgetsBindingObserver {
  final _auth = AdminAuthService();
  Timer? _timer;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _verify());
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verify();
  }

  Future<void> _verify() async {
    if (!mounted || _redirecting || _auth.sessionAuthorized) return;
    if (!_auth.claimExpiredSessionRedirect()) return;
    _redirecting = true;
    await AuditService().record(
      category: 'SEGURIDAD',
      action: 'SESIÓN ADMINISTRATIVA BLOQUEADA',
      detail: 'El panel se bloqueó automáticamente después de 15 minutos sin actividad.',
    );
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.adminAuth,
      (route) => route.settings.name == AppRoutes.login,
    );
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _auth.touchSession(),
        child: widget.child,
      );
}
