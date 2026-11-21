import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/meta.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/data_providers.dart';
import 'auth_widgets.dart';

/// Écrans possibles de la carte.
enum AuthMode { signIn, signUp, verifyEmail, forgot, reset, pending }

/// Carte « YOUR SPACE » de la maquette, adaptée à C-Tech :
/// connexion, inscription, code e-mail (double authentification),
/// mot de passe oublié et compte en attente de validation.
class AuthCard extends ConsumerStatefulWidget {
  const AuthCard({super.key, required this.accent, required this.glow});

  /// Couleur de la lampe.
  final Color accent;

  /// Intensité de la lumière (0..1) pour le halo autour de la carte.
  final double glow;

  @override
  ConsumerState<AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends ConsumerState<AuthCard> {
  AuthMode _mode = AuthMode.signIn;
  String _email = '';

  void _go(AuthMode mode, {String? email}) => setState(() {
        _mode = mode;
        if (email != null) _email = email;
      });

  /// En développement (pas de SMTP), l'API renvoie le code : on l'affiche.
  void _showDebugCode(CodeSent sent) {
    if (sent.debugCode == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mode développement — code : ${sent.debugCode}'), duration: const Duration(seconds: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_mode) {
      AuthMode.signIn => ('Bienvenue', 'Connectez-vous pour voir vos tâches'),
      AuthMode.signUp => ('Inscription', 'Rejoignez l\'espace de votre département'),
      AuthMode.verifyEmail => ('Vérification', 'Entrez le code envoyé à $_email'),
      AuthMode.forgot => ('Mot de passe oublié', 'Recevez un code par e-mail'),
      AuthMode.reset => ('Nouveau mot de passe', 'Code envoyé à $_email'),
      AuthMode.pending => ('Presque prêt', 'Votre compte attend la validation'),
    };

    return Theme(
      data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: widget.accent)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1B1F).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(color: widget.accent.withValues(alpha: 0.22 * widget.glow), blurRadius: 60, spreadRadius: 2),
            const BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 18)),
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('C-TECH TASKS',
                    style: GoogleFonts.manrope(
                        color: widget.accent, fontSize: 11, letterSpacing: 2.4, fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.accent, shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 16),
              Text(title, style: AppTheme.display(34, color: Colors.white)),
              const SizedBox(height: 6),
              Text(subtitle, style: GoogleFonts.manrope(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 18),
              if (_mode == AuthMode.signIn || _mode == AuthMode.signUp) ...[
                _Tabs(
                  accent: widget.accent,
                  signUp: _mode == AuthMode.signUp,
                  onChanged: (signUp) => _go(signUp ? AuthMode.signUp : AuthMode.signIn),
                ),
                const SizedBox(height: 18),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey(_mode), child: _body()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() => switch (_mode) {
        AuthMode.signIn => _SignInForm(accent: widget.accent, onNavigate: _go, onCodeSent: _showDebugCode),
        AuthMode.signUp => _SignUpForm(accent: widget.accent, onNavigate: _go, onCodeSent: _showDebugCode),
        AuthMode.verifyEmail =>
          _VerifyForm(accent: widget.accent, email: _email, onNavigate: _go, onCodeSent: _showDebugCode),
        AuthMode.forgot => _ForgotForm(accent: widget.accent, onNavigate: _go, onCodeSent: _showDebugCode),
        AuthMode.reset => _ResetForm(accent: widget.accent, email: _email, onNavigate: _go),
        AuthMode.pending => _PendingView(accent: widget.accent, onNavigate: _go),
      };
}

typedef _Navigate = void Function(AuthMode mode, {String? email});

/// Onglets « Connexion / Inscription » soulignés.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.accent, required this.signUp, required this.onChanged});
  final Color accent;
  final bool signUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool selected, bool value) => InkWell(
          onTap: () => onChanged(value),
          child: Container(
            padding: const EdgeInsets.only(bottom: 8, right: 4),
            margin: const EdgeInsets.only(right: 22),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: selected ? accent : Colors.transparent, width: 2)),
            ),
            child: Text(label,
                style: GoogleFonts.manrope(
                    color: selected ? Colors.white : Colors.white54, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        );
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
      child: Row(children: [tab('Connexion', !signUp, false), tab('Inscription', signUp, true)]),
    );
  }
}

// ============================================================== Connexion

class _SignInForm extends ConsumerStatefulWidget {
  const _SignInForm({required this.accent, required this.onNavigate, required this.onCodeSent});
  final Color accent;
  final _Navigate onNavigate;
  final void Function(CodeSent) onCodeSent;

  @override
  ConsumerState<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<_SignInForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signIn(_email.text, _password.text, remember: _remember);
    } on ApiException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'EMAIL_NOT_VERIFIED':
          widget.onNavigate(AuthMode.verifyEmail, email: _email.text.trim());
          return;
        case 'ACCOUNT_PENDING':
          widget.onNavigate(AuthMode.pending, email: _email.text.trim());
          return;
        default:
          setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(children: [
          AuthError(_error),
          AuthField(
            label: 'Adresse e-mail',
            hint: 'prenom.nom@exemple.com',
            controller: _email,
            icon: Icons.person_outline,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: Validators.email,
          ),
          AuthField(
            label: 'Mot de passe',
            hint: 'Votre mot de passe',
            controller: _password,
            icon: Icons.lock_outline,
            obscure: true,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: Validators.required,
            trailing: GestureDetector(
              onTap: () => widget.onNavigate(AuthMode.forgot),
              child: Text('Oublié ?', style: TextStyle(color: widget.accent, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          Row(children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _remember,
                activeColor: widget.accent,
                side: const BorderSide(color: Colors.white38),
                onChanged: (v) => setState(() => _remember = v ?? false),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Se souvenir de moi', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
          const SizedBox(height: 18),
          AccentButton(label: 'Se connecter', color: widget.accent, loading: _loading, onPressed: _submit),
        ]),
      ),
    );
  }
}

// ============================================================== Inscription

class _SignUpForm extends ConsumerStatefulWidget {
  const _SignUpForm({required this.accent, required this.onNavigate, required this.onCodeSent});
  final Color accent;
  final _Navigate onNavigate;
  final void Function(CodeSent) onCodeSent;

  @override
  ConsumerState<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends ConsumerState<_SignUpForm> {
  final _form = GlobalKey<FormState>();
  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  int? _departmentId;
  String? _position;
  bool _acceptTerms = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_lastName, _firstName, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_acceptTerms) {
      setState(() => _error = 'Vous devez accepter les conditions d\'utilisation.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sent = await ref.read(authRepositoryProvider).register(
            firstName: _firstName.text,
            lastName: _lastName.text,
            email: _email.text,
            departmentId: _departmentId!,
            position: _position!,
            password: _password.text,
            passwordConfirmation: _confirm.text,
            acceptTerms: _acceptTerms,
          );
      if (!mounted) return;
      widget.onCodeSent(sent);
      widget.onNavigate(AuthMode.verifyEmail, email: _email.text.trim());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(metaProvider);

    return meta.when(
      loading: () => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Column(children: [
        AuthError('Impossible de charger les départements : $e'),
        TextButton(onPressed: () => ref.invalidate(metaProvider), child: const Text('Réessayer')),
      ]),
      data: (meta) => _buildForm(meta),
    );
  }

  Widget _buildForm(Meta meta) {
    final positions = _departmentId == null ? const <Option>[] : (meta.positions[_departmentId] ?? const <Option>[]);

    return Form(
      key: _form,
      child: Column(children: [
        AuthError(_error),
        LayoutBuilder(builder: (context, c) {
          final lastName = AuthField(label: 'Nom', hint: 'Nom', controller: _lastName, icon: Icons.badge_outlined, validator: Validators.required);
          final firstName = AuthField(label: 'Prénom', hint: 'Prénom', controller: _firstName, icon: Icons.badge_outlined, validator: Validators.required);
          // Côte à côte si la carte est assez large.
          return c.maxWidth > 330
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: lastName),
                  const SizedBox(width: 10),
                  Expanded(child: firstName),
                ])
              : Column(children: [lastName, firstName]);
        }),
        AuthField(
          label: 'Adresse e-mail',
          hint: 'prenom.nom@exemple.com',
          controller: _email,
          icon: Icons.alternate_email,
          keyboardType: TextInputType.emailAddress,
          validator: Validators.email,
        ),
        AuthDropdown<int>(
          label: 'Département',
          icon: Icons.apartment_outlined,
          hint: 'Choisir un département',
          value: _departmentId,
          items: [for (final d in meta.departments) DropdownMenuItem(value: d.id, child: Text(d.name))],
          validator: (v) => v == null ? 'Choisissez un département' : null,
          onChanged: (v) => setState(() {
            _departmentId = v;
            _position = null; // les postes dépendent du département
          }),
        ),
        AuthDropdown<String>(
          label: 'Poste',
          icon: Icons.workspace_premium_outlined,
          hint: _departmentId == null ? 'Choisissez d\'abord un département' : 'Choisir un poste',
          value: _position,
          items: [for (final p in positions) DropdownMenuItem(value: p.value, child: Text(p.label))],
          validator: (v) => v == null ? 'Choisissez un poste' : null,
          onChanged: (v) => setState(() => _position = v),
        ),
        AuthField(
          label: 'Mot de passe',
          hint: '8 caractères, Aa1',
          controller: _password,
          icon: Icons.lock_outline,
          obscure: true,
          validator: Validators.password,
        ),
        AuthField(
          label: 'Confirmer le mot de passe',
          hint: 'Retapez le mot de passe',
          controller: _confirm,
          icon: Icons.lock_outline,
          obscure: true,
          textInputAction: TextInputAction.done,
          validator: (v) => v != _password.text ? 'Les mots de passe ne correspondent pas' : null,
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _acceptTerms,
              activeColor: widget.accent,
              side: const BorderSide(color: Colors.white38),
              onChanged: (v) => setState(() => _acceptTerms = v ?? false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(children: [
              const Text('J\'accepte les ', style: TextStyle(color: Colors.white70, fontSize: 13)),
              GestureDetector(
                onTap: () => _showTerms(context),
                child: Text('conditions d\'utilisation',
                    style: TextStyle(color: widget.accent, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        AccentButton(label: 'Créer le compte', color: widget.accent, loading: _loading, onPressed: _submit),
      ]),
    );
  }

  void _showTerms(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Conditions d\'utilisation'),
          content: const SingleChildScrollView(
            child: Text(
              'C-Tech Tasks est réservé aux membres du Club-Tech (C-Tech).\n\n'
              '• Chaque compte est personnel et validé par le bureau.\n'
              '• Les tâches et commentaires concernent uniquement les activités du club.\n'
              '• Vos nom, prénom, e-mail, département et poste sont visibles des membres '
              'concernés par vos tâches. Ils ne sont jamais partagés hors du club.\n'
              '• Votre accusé de lecture (reçu, vu, effectué) est visible par l\'auteur de la tâche.\n'
              '• Tout usage abusif peut entraîner la suspension du compte.',
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
        ),
      );
}

// ============================================================== Code e-mail (double authentification)

class _VerifyForm extends ConsumerStatefulWidget {
  const _VerifyForm({required this.accent, required this.email, required this.onNavigate, required this.onCodeSent});
  final Color accent;
  final String email;
  final _Navigate onNavigate;
  final void Function(CodeSent) onCodeSent;

  @override
  ConsumerState<_VerifyForm> createState() => _VerifyFormState();
}

class _VerifyFormState extends ConsumerState<_VerifyForm> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyEmail(widget.email, _code.text);
      if (mounted) widget.onNavigate(AuthMode.pending);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      final sent = await ref.read(authRepositoryProvider).resendCode(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sent.message)));
      widget.onCodeSent(sent);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(children: [
        AuthError(_error),
        AuthField(
          label: 'Code à 6 chiffres',
          hint: '••••••',
          controller: _code,
          icon: Icons.verified_user_outlined,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          validator: Validators.code,
        ),
        AccentButton(label: 'Vérifier', color: widget.accent, loading: _loading, onPressed: _submit),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton(onPressed: () => widget.onNavigate(AuthMode.signIn), child: const Text('Retour')),
          TextButton(onPressed: _resend, child: const Text('Renvoyer le code')),
        ]),
      ]),
    );
  }
}

// ============================================================== Mot de passe oublié

class _ForgotForm extends ConsumerStatefulWidget {
  const _ForgotForm({required this.accent, required this.onNavigate, required this.onCodeSent});
  final Color accent;
  final _Navigate onNavigate;
  final void Function(CodeSent) onCodeSent;

  @override
  ConsumerState<_ForgotForm> createState() => _ForgotFormState();
}

class _ForgotFormState extends ConsumerState<_ForgotForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sent = await ref.read(authRepositoryProvider).forgotPassword(_email.text);
      if (!mounted) return;
      widget.onCodeSent(sent);
      widget.onNavigate(AuthMode.reset, email: _email.text.trim());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(children: [
        AuthError(_error),
        AuthField(
          label: 'Adresse e-mail',
          hint: 'prenom.nom@exemple.com',
          controller: _email,
          icon: Icons.alternate_email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          validator: Validators.email,
        ),
        AccentButton(label: 'Envoyer le code', color: widget.accent, loading: _loading, onPressed: _submit),
        const SizedBox(height: 10),
        TextButton(onPressed: () => widget.onNavigate(AuthMode.signIn), child: const Text('Retour à la connexion')),
      ]),
    );
  }
}

class _ResetForm extends ConsumerStatefulWidget {
  const _ResetForm({required this.accent, required this.email, required this.onNavigate});
  final Color accent;
  final String email;
  final _Navigate onNavigate;

  @override
  ConsumerState<_ResetForm> createState() => _ResetFormState();
}

class _ResetFormState extends ConsumerState<_ResetForm> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final message =
          await ref.read(authRepositoryProvider).resetPassword(widget.email, _code.text, _password.text, _confirm.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      widget.onNavigate(AuthMode.signIn);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(children: [
        AuthError(_error),
        AuthField(
          label: 'Code reçu',
          hint: '••••••',
          controller: _code,
          icon: Icons.pin_outlined,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: Validators.code,
        ),
        AuthField(
          label: 'Nouveau mot de passe',
          hint: '8 caractères, Aa1',
          controller: _password,
          icon: Icons.lock_outline,
          obscure: true,
          validator: Validators.password,
        ),
        AuthField(
          label: 'Confirmer',
          hint: 'Retapez le mot de passe',
          controller: _confirm,
          icon: Icons.lock_outline,
          obscure: true,
          textInputAction: TextInputAction.done,
          validator: (v) => v != _password.text ? 'Les mots de passe ne correspondent pas' : null,
        ),
        AccentButton(label: 'Changer le mot de passe', color: widget.accent, loading: _loading, onPressed: _submit),
        const SizedBox(height: 10),
        TextButton(onPressed: () => widget.onNavigate(AuthMode.signIn), child: const Text('Annuler')),
      ]),
    );
  }
}

// ============================================================== Compte en attente

class _PendingView extends StatelessWidget {
  const _PendingView({required this.accent, required this.onNavigate});
  final Color accent;
  final _Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(Icons.hourglass_top_rounded, size: 46, color: accent),
      const SizedBox(height: 12),
      const Text(
        'Votre adresse e-mail est confirmée. Le président, le vice-président '
        'ou le responsable de votre département doit maintenant valider votre compte. '
        'Vous pourrez ensuite vous connecter.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, height: 1.5),
      ),
      const SizedBox(height: 20),
      AccentButton(label: 'Retour à la connexion', color: accent, onPressed: () => onNavigate(AuthMode.signIn)),
    ]);
  }
}
