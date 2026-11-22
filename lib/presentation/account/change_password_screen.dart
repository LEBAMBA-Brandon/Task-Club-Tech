import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/responsive.dart';
import '../../providers/core_providers.dart';
import '../auth/widgets/auth_widgets.dart' show Validators;
import '../common/common_widgets.dart';

/// Changement du mot de passe depuis le profil.
/// Les autres appareils connectés sont déconnectés ; celui-ci reste connecté.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidden = true;
  bool _saving = false;
  Map<String, String> _serverErrors = const {};

  @override
  void dispose() {
    for (final c in [_current, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = const {});
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final message =
          await ref.read(authRepositoryProvider).changePassword(_current.text, _password.text, _confirm.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.fieldErrors.isNotEmpty) {
        setState(() => _serverErrors = e.fieldErrors);
        _form.currentState!.validate();
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Afficher' : 'Masquer',
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Changer le mot de passe')),
      body: MaxWidth(
        maxWidth: 520,
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              controller: _current,
              obscureText: _hidden,
              decoration: _decoration('Mot de passe actuel'),
              validator: (v) => Validators.required(v) ?? _serverErrors['current_password'],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _hidden,
              decoration: _decoration('Nouveau mot de passe'),
              validator: (v) => Validators.password(v) ?? _serverErrors['password'],
            ),
            const SizedBox(height: 6),
            const Text('8 caractères minimum, avec une majuscule, une minuscule et un chiffre.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: _hidden,
              decoration: _decoration('Confirmer le nouveau mot de passe'),
              validator: (v) => v != _password.text ? 'Les mots de passe ne correspondent pas' : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: const Text('Enregistrer'),
            ),
          ]),
        ),
      ),
    );
  }
}
