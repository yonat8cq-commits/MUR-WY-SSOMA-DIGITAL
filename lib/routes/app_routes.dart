import 'package:flutter/material.dart';
import '../screens/login/login_page.dart';
import '../screens/login/admin_auth_page.dart';
import '../screens/worker/worker_home_page.dart';
import '../screens/admin/admin_dashboard_page.dart';
import '../screens/admin/signature_tracking_page.dart';
import '../screens/admin/authorized_signatures_page.dart';
import '../screens/admin/workers_admin_page.dart';
import '../screens/admin/companies_admin_page.dart';
import '../screens/admin/consents_admin_page.dart';
import '../screens/admin/historical_documents_page.dart';
import '../screens/admin/reminders_page.dart';
import '../screens/admin/audit_log_page.dart';
import '../screens/admin/backup_page.dart';
import '../screens/admin/admin_security_page.dart';
import '../screens/admin/sync_status_page.dart';
import '../screens/admin/admin_session_guard.dart';

class AppRoutes {
  static const login = '/';
  static const workerHome = '/trabajador';
  static const adminHome = '/administrador';
  static const adminAuth = '/acceso-administrador';
  static const signatureTracking = '/administrador/seguimiento';
  static const authorizedSignatures = '/administrador/firmas-autorizadas';
  static const workersAdmin = '/administrador/trabajadores';
  static const companiesAdmin = '/administrador/empresas';
  static const consentsAdmin = '/administrador/consentimientos';
  static const historicalDocuments = '/administrador/archivo-historico';
  static const reminders = '/administrador/alertas';
  static const auditLog = '/administrador/auditoria';
  static const backup = '/administrador/respaldo';
  static const adminSecurity = '/administrador/seguridad';
  static const syncStatus = '/administrador/sincronizacion';

  static final Map<String, WidgetBuilder> routes = {
    login: (_) => const LoginPage(),
    workerHome: (_) => const WorkerHomePage(),
    adminHome: (_) => _admin(const AdminDashboardPage()),
    adminAuth: (_) => const AdminAuthPage(),
    signatureTracking: (_) => _admin(const SignatureTrackingPage()),
    authorizedSignatures: (_) => _admin(const AuthorizedSignaturesPage()),
    workersAdmin: (_) => _admin(const WorkersAdminPage()),
    companiesAdmin: (_) => _admin(const CompaniesAdminPage()),
    consentsAdmin: (_) => _admin(const ConsentsAdminPage()),
    historicalDocuments: (_) => _admin(const HistoricalDocumentsPage()),
    reminders: (_) => _admin(const RemindersPage()),
    auditLog: (_) => _admin(const AuditLogPage()),
    backup: (_) => _admin(const BackupPage()),
    adminSecurity: (_) => _admin(const AdminSecurityPage()),
    syncStatus: (_) => _admin(const SyncStatusPage()),
  };

  static Widget _admin(Widget page) => AdminSessionGuard(child: page);
}
