import 'package:flutter/material.dart';

import '../../services/admin_auth_service.dart';

class AdminSecurityPage extends StatefulWidget {
  const AdminSecurityPage({super.key});

  @override
  State<AdminSecurityPage> createState() => _AdminSecurityPageState();
}

class _AdminSecurityPageState extends State<AdminSecurityPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirmation = true;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final code = await AdminAuthService().changePassword(
      _current.text,
      _newPassword.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La contraseña administrativa actual no es correcta.'),
      ));
      return;
    }
    _current.clear();
    _newPassword.clear();
    _confirmation.clear();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.key, size: 48, color: Color(0xFFF3B41B)),
        title: const Text('Nuevo código de recuperación'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'El código anterior ya no funciona. Guarda este nuevo código fuera del celular; se mostrará una sola vez.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SelectableText(code, style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ]),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('YA LO GUARDÉ'),
          ),
        ],
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente.')),
      );
    }
  }

  InputDecoration _decoration(
    String label,
    bool obscure,
    VoidCallback toggle,
  ) => InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: toggle,
          icon: Icon(obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Seguridad de la cuenta')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Icon(Icons.admin_panel_settings_outlined,
                          size: 62, color: Color(0xFFF3B41B)),
                      const SizedBox(height: 12),
                      const Text('Cambiar contraseña administrativa',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text(
                        'La nueva contraseña debe tener al menos 10 caracteres, una letra y un número.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _current,
                        obscureText: _obscureCurrent,
                        decoration: _decoration('Contraseña actual', _obscureCurrent,
                            () => setState(() => _obscureCurrent = !_obscureCurrent)),
                        validator: (value) => (value ?? '').isEmpty
                            ? 'Ingresa tu contraseña actual.' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _newPassword,
                        obscureText: _obscureNew,
                        decoration: _decoration('Nueva contraseña', _obscureNew,
                            () => setState(() => _obscureNew = !_obscureNew)),
                        validator: (value) {
                          final text = value ?? '';
                          if (text.length < 10 ||
                              !RegExp(r'[A-Za-z]').hasMatch(text) ||
                              !RegExp(r'\d').hasMatch(text)) {
                            return 'Usa 10 caracteres como mínimo, una letra y un número.';
                          }
                          if (text == _current.text) {
                            return 'La nueva contraseña debe ser diferente.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmation,
                        obscureText: _obscureConfirmation,
                        decoration: _decoration('Confirmar nueva contraseña',
                            _obscureConfirmation,
                            () => setState(() => _obscureConfirmation = !_obscureConfirmation)),
                        validator: (value) => value == _newPassword.text
                            ? null : 'Las contraseñas no coinciden.',
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _saving ? null : _change,
                        icon: _saving
                            ? const SizedBox.square(dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.password),
                        label: Text(_saving ? 'ACTUALIZANDO…' : 'CAMBIAR CONTRASEÑA'),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
