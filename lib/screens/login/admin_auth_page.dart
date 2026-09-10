import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/admin_auth_service.dart';

class AdminAuthPage extends StatefulWidget {
  const AdminAuthPage({super.key});

  @override
  State<AdminAuthPage> createState() => _AdminAuthPageState();
}

class _AdminAuthPageState extends State<AdminAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _service = AdminAuthService();
  bool _loading = true;
  bool _configured = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final configured = await _service.isConfigured;
    if (!mounted) return;
    setState(() {
      _configured = configured;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    String? recoveryCode;
    final bool valid;
    if (_configured) {
      valid = await _service.login(_password.text);
      if (valid) recoveryCode = await _service.ensureRecoveryCode();
    } else {
      recoveryCode = await _service.configure(_password.text);
      valid = true;
    }
    if (!mounted) return;
    if (!valid) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña administrativa no es correcta.')),
      );
      return;
    }
    if (recoveryCode != null) {
      await _showRecoveryCode(recoveryCode);
      if (!mounted) return;
    }
    _openAdmin();
  }

  void _openAdmin() => Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.adminHome,
      (route) => route.settings.name == AppRoutes.login,
    );

  Future<void> _showRecoveryCode(String code) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.key, size: 48, color: Color(0xFFF3B41B)),
          title: const Text('Guarda tu código de recuperación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Este código se mostrará una sola vez. Anótalo y guárdalo fuera del celular.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('YA LO GUARDÉ'),
            ),
          ],
        ),
      );

  Future<void> _recoverAccess() async {
    final recovery = TextEditingController();
    final newPassword = TextEditingController();
    final confirmation = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recuperar acceso'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: recovery,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Código de recuperación', prefixIcon: Icon(Icons.key)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nueva contraseña', prefixIcon: Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmar contraseña', prefixIcon: Icon(Icons.verified_user_outlined)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCELAR')),
          FilledButton(
            onPressed: () {
              final password = newPassword.text;
              if (recovery.text.trim().isEmpty || password.length < 10 || !RegExp(r'[A-Za-z]').hasMatch(password) || !RegExp(r'\d').hasMatch(password) || password != confirmation.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Verifica el código y usa una contraseña de 10 caracteres, con letra y número.')),
                );
                return;
              }
              Navigator.pop(dialogContext, [recovery.text, password]);
            },
            child: const Text('RESTABLECER'),
          ),
        ],
      ),
    );
    recovery.dispose();
    newPassword.dispose();
    confirmation.dispose();
    if (result == null) return;
    setState(() => _loading = true);
    final newCode = await _service.resetWithRecoveryCode(result[0], result[1]);
    if (!mounted) return;
    if (newCode == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El código de recuperación no es válido.')),
      );
      return;
    }
    await _showRecoveryCode(newCode);
    if (!mounted) return;
    _openAdmin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso administrativo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    elevation: 0,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.admin_panel_settings, size: 62, color: Color(0xFFF3B41B)),
                            const SizedBox(height: 16),
                            Text(
                              _configured ? 'Ingreso del super administrador' : 'Configurar super administrador',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'CUTIPA QUISPE JHONATHAN\nAsistente SSOMA',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF626B7A)),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                labelText: _configured ? 'Contraseña administrativa' : 'Crear contraseña administrativa',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                ),
                              ),
                              validator: (value) {
                                if (_configured) return (value ?? '').isEmpty ? 'Ingresa tu contraseña.' : null;
                                final text = value ?? '';
                                if (text.length < 10 || !RegExp(r'[A-Za-z]').hasMatch(text) || !RegExp(r'\d').hasMatch(text)) {
                                  return 'Usa 10 caracteres como mínimo, una letra y un número.';
                                }
                                return null;
                              },
                              onFieldSubmitted: _configured ? (_) => _submit() : null,
                            ),
                            if (!_configured) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _confirmation,
                                obscureText: true,
                                decoration: const InputDecoration(labelText: 'Confirmar contraseña', prefixIcon: Icon(Icons.verified_user_outlined)),
                                validator: (value) => value == _password.text ? null : 'Las contraseñas no coinciden.',
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Guarda esta contraseña en un lugar seguro. Será necesaria para administrar trabajadores, firmas y documentos.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF626B7A)),
                              ),
                            ],
                            const SizedBox(height: 22),
                            ElevatedButton.icon(
                              onPressed: _loading ? null : _submit,
                              icon: const Icon(Icons.login),
                              label: Text(_configured ? 'INGRESAR' : 'CREAR ACCESO SEGURO'),
                            ),
                            if (_configured)
                              TextButton.icon(
                                onPressed: _loading ? null : _recoverAccess,
                                icon: const Icon(Icons.key_outlined),
                                label: const Text('OLVIDÉ MI CONTRASEÑA'),
                              ),
                          ],
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
