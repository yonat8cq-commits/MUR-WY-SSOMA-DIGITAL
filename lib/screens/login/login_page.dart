import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/offline_workflow_service.dart';
import '../../services/worker_data_service.dart';
import '../../services/worker_admin_service.dart';
import '../../services/password_service.dart';
import '../onboarding/change_password_page.dart';
import '../onboarding/consent_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _dniController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _sharedDevice = false;

  @override
  void dispose() {
    _dniController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final dni = _dniController.text;
    final workerData = WorkerDataService();
    final hasWorkers = await workerData.hasImportedWorkers();
    final profile = await workerData.loadProfile(dni);
    if (hasWorkers && profile == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El DNI no está registrado en las capacitaciones importadas.',
          ),
        ),
      );
      return;
    }
    if (profile != null && !profile.active) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La cuenta está inactiva. Comunícate con SSOMA.'),
        ),
      );
      return;
    }
    if (profile?.requiresPasswordChange == true &&
        _passwordController.text != WorkerAdminService.temporaryPassword) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña temporal no es correcta.')),
      );
      return;
    }
    if (profile != null &&
        !profile.requiresPasswordChange &&
        !await PasswordService().verify(dni, _passwordController.text)) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña no es correcta.')),
      );
      return;
    }
    final workflow = OfflineWorkflowService.instance;
    await workflow.setSharedDeviceMode(_sharedDevice);
    await workflow.openSession(dni);
    final changed = profile == null
        ? await workflow.passwordWasChanged(dni)
        : !profile.requiresPasswordChange;
    final consented = await workflow.consentWasAccepted(dni);
    if (!mounted) return;

    if (!changed) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ChangePasswordPage(dni: dni)),
      );
    } else if (!consented) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ConsentPage(dni: dni)),
      );
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.workerHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(Icons.health_and_safety_rounded, size: 64, color: Color(0xFFF3B41B)),
                        ),
                        const SizedBox(height: 20),
                        Text('MUR WY SSOMA DIGITAL', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text('Ingresa para revisar y firmar tus capacitaciones.', style: TextStyle(color: Color(0xFF626B7A), fontSize: 16)),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _dniController,
                          keyboardType: TextInputType.number,
                          maxLength: 8,
                          decoration: const InputDecoration(labelText: 'DNI', prefixIcon: Icon(Icons.badge_outlined), counterText: ''),
                          validator: (value) => RegExp(r'^\d{8}$').hasMatch(value ?? '') ? null : 'Ingresa un DNI de 8 dígitos',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                          validator: (value) => (value ?? '').length >= 6 ? null : 'La contraseña debe tener al menos 6 caracteres',
                          onFieldSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          value: _sharedDevice,
                          onChanged: (value) => setState(
                            () => _sharedDevice = value ?? false,
                          ),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'Estoy usando un celular compartido',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'La sesión se cerrará automáticamente después de firmar.',
                          ),
                        ),
                        const SizedBox(height: 22),
                        ElevatedButton(
                          onPressed: _loading ? null : _login,
                          child: Text(_loading ? 'VALIDANDO…' : 'INGRESAR'),
                        ),
                        TextButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicita a SSOMA el restablecimiento de tu contraseña.'))), child: const Text('¿Olvidaste tu contraseña?')),
                        const Divider(height: 28),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.adminHome,
                          ),
                          icon: const Icon(Icons.admin_panel_settings_outlined),
                          label: const Text('ACCESO ADMINISTRADOR (PRUEBA)'),
                        ),
                        const SizedBox(height: 12),
                        const Text('Versión de prueba • Los accesos reales serán creados por el administrador SSOMA.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF7B8492))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
