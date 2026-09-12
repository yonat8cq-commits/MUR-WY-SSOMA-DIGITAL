import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/offline_workflow_service.dart';
import '../../services/worker_data_service.dart';
import '../../services/worker_admin_service.dart';
import '../../services/password_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/remembered_credentials_service.dart';
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
  bool _rememberPassword = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final credentials = await RememberedCredentialsService().load();
    if (!mounted || credentials == null) return;
    setState(() {
      _dniController.text = credentials.dni;
      _passwordController.text = credentials.password;
      _rememberPassword = true;
    });
  }

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
    final centralLogin = await FirebaseAuthService.instance.signInWorker(
      dni: dni,
      password: _passwordController.text,
    );
    final workflow = OfflineWorkflowService.instance;
    await workflow.setSharedDeviceMode(_sharedDevice);
    await workflow.openSession(dni);
    if (_rememberPassword && !_sharedDevice) {
      await RememberedCredentialsService().save(
        dni,
        _passwordController.text,
      );
    } else {
      await RememberedCredentialsService().clear();
    }
    final changed = profile == null
        ? await workflow.passwordWasChanged(dni)
        : !profile.requiresPasswordChange;
    final consented = await workflow.consentWasAccepted(dni);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(centralLogin == CentralLoginResult.authenticated
            ? 'Sesión central protegida y conectada.'
            : 'Ingreso local: los cambios se sincronizarán al recuperar conexión.'),
      ),
    );

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
      backgroundColor: const Color(0xFF15191F),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF11151A), Color(0xFF303740)],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 18,
                color: Colors.white,
                shadowColor: Colors.black54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _MurWyBrand(),
                        const SizedBox(height: 20),
                        Text('MUR WY SSOMA DIGITAL', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF252A30))),
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
                          value: _rememberPassword,
                          onChanged: _sharedDevice
                              ? null
                              : (value) => setState(
                                    () => _rememberPassword = value ?? false,
                                  ),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'Recordar DNI y contraseña',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Se guardarán cifrados únicamente en este celular.',
                          ),
                        ),
                        CheckboxListTile(
                          value: _sharedDevice,
                          onChanged: (value) {
                            setState(() {
                              _sharedDevice = value ?? false;
                              if (_sharedDevice) _rememberPassword = false;
                            });
                            if (_sharedDevice) {
                              RememberedCredentialsService().clear();
                            }
                          },
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
                            AppRoutes.adminAuth,
                          ),
                          icon: const Icon(Icons.admin_panel_settings_outlined),
                          label: const Text('ACCESO SUPER ADMINISTRADOR'),
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
      ),
    );
  }
}

class _MurWyBrand extends StatelessWidget {
  const _MurWyBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 76,
          height: 76,
          child: CustomPaint(painter: _MurWyMarkPainter()),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MUR',
                style: TextStyle(
                  fontSize: 42,
                  height: .9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Color(0xFF36383B),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'SERVICIOS MINEROS,\nMANTENIMIENTO Y TRANSPORTE',
                style: TextStyle(
                  fontSize: 8.5,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MurWyMarkPainter extends CustomPainter {
  const _MurWyMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final yellow = Paint()..color = const Color(0xFFF3B41B);
    final graphite = Paint()..color = const Color(0xFF3A3C3F);
    final top = Path()
      ..moveTo(size.width * .5, 0)
      ..lineTo(size.width * .86, size.height * .55)
      ..lineTo(size.width * .5, size.height * .43)
      ..lineTo(size.width * .14, size.height * .55)
      ..close();
    final bottom = Path()
      ..moveTo(size.width * .04, size.height)
      ..lineTo(size.width * .32, size.height * .62)
      ..lineTo(size.width * .5, size.height * .49)
      ..lineTo(size.width * .68, size.height * .62)
      ..lineTo(size.width * .96, size.height)
      ..lineTo(size.width * .68, size.height)
      ..lineTo(size.width * .5, size.height * .72)
      ..lineTo(size.width * .32, size.height)
      ..close();
    canvas.drawPath(top, yellow);
    canvas.drawPath(bottom, graphite);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
