import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/offline_workflow_service.dart';
import '../../services/password_service.dart';
import '../../services/firebase_auth_service.dart';
import 'consent_page.dart';

class ChangePasswordPage extends StatefulWidget {
  final String dni;
  const ChangePasswordPage({super.key, required this.dni});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await PasswordService().setPassword(widget.dni, _password.text);
    await FirebaseAuthService.instance.updateCurrentPassword(_password.text);
    await OfflineWorkflowService.instance.markPasswordChanged(widget.dni);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ConsentPage(dni: widget.dni)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguridad de la cuenta'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.password_rounded, size: 64, color: Color(0xFFF3B41B)),
          const SizedBox(height: 18),
          const Text(
            'Crea tu contraseña personal',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'La contraseña temporal solo puede utilizarse una vez.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF626B7A)),
          ),
          const SizedBox(height: 28),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    helperText: 'Mínimo 8 caracteres, una letra y un número.',
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final text = value ?? '';
                    if (text.length < 8 ||
                        !RegExp(r'[A-Za-z]').hasMatch(text) ||
                        !RegExp(r'\d').hasMatch(text)) {
                      return 'La contraseña no cumple los requisitos.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _confirmation,
                  obscureText: _obscureConfirmation,
                  decoration: InputDecoration(
                    labelText: 'Repite la contraseña',
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscureConfirmation = !_obscureConfirmation,
                      ),
                      icon: Icon(
                        _obscureConfirmation
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      value == _password.text ? null : 'Las contraseñas no coinciden.',
                ),
                const SizedBox(height: 26),
                ElevatedButton(
                  onPressed: _saving ? null : _continue,
                  child: Text(_saving ? 'GUARDANDO…' : 'GUARDAR Y CONTINUAR'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  ),
                  child: const Text('CANCELAR'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
