import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/social_auth_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/core_providers.dart';
import 'auth_widgets.dart';

/// Boutons « Continuer avec Google / GitHub ».
///
/// Déroulé : connexion chez Google ou GitHub (Firebase) -> jeton envoyé à l'API.
///  - compte actif           : l'utilisateur est connecté ;
///  - nouveau compte         : [onProfileRequired] ouvre le formulaire « Dernière étape » ;
///  - compte en attente      : [onPending] affiche « Presque prêt ».
class SocialButtons extends ConsumerStatefulWidget {
  const SocialButtons({super.key, required this.accent, required this.onProfileRequired, required this.onPending});

  final Color accent;
  final void Function(String idToken, Map<String, dynamic> data) onProfileRequired;
  final VoidCallback onPending;

  @override
  ConsumerState<SocialButtons> createState() => _SocialButtonsState();
}

class _SocialButtonsState extends ConsumerState<SocialButtons> {
  SocialProvider? _loading;
  String? _error;

  Future<void> _signIn(SocialProvider provider) async {
    setState(() {
      _loading = provider;
      _error = null;
    });
    String? idToken;
    try {
      idToken = await ref.read(socialAuthProvider).signIn(provider);
      await ref.read(authControllerProvider.notifier).signInSocial(idToken);
    } on SocialAuthException catch (e) {
      if (mounted && !e.cancelled) setState(() => _error = e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      final token = idToken;
      if (e.code == 'PROFILE_REQUIRED' && token != null) {
        widget.onProfileRequired(token, e.data);
      } else if (e.code == 'ACCOUNT_PENDING') {
        widget.onPending();
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.read(socialAuthProvider).isSupported) return const SizedBox.shrink();

    return Column(children: [
      const SizedBox(height: 16),
      const Row(children: [
        Expanded(child: Divider(color: Colors.white12)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('ou continuer avec', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        Expanded(child: Divider(color: Colors.white12)),
      ]),
      const SizedBox(height: 12),
      if (_error != null) AuthError(_error),
      Row(children: [
        Expanded(
          child: _ProviderButton(
            label: 'Google',
            badge: const _GoogleBadge(),
            loading: _loading == SocialProvider.google,
            onPressed: _loading == null ? () => _signIn(SocialProvider.google) : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ProviderButton(
            label: 'GitHub',
            badge: const Icon(Icons.code_rounded, size: 18, color: Colors.white),
            loading: _loading == SocialProvider.github,
            onPressed: _loading == null ? () => _signIn(SocialProvider.github) : null,
          ),
        ),
      ]),
    ]);
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({required this.label, required this.badge, required this.loading, required this.onPressed});
  final String label;
  final Widget badge;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
            backgroundColor: Colors.white.withValues(alpha: 0.04),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onPressed,
          child: loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  badge,
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
        ),
      );
}

/// « G » coloré (évite d'embarquer le logo officiel).
class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) => Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 13)),
      );
}
