import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/social_auth_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/core_providers.dart';
import 'auth_widgets.dart';

/// Bouton « Continuer avec Google ».
///
/// Déroulé : connexion Google (Firebase) -> jeton envoyé à l'API.
///  - compte actif      : l'utilisateur est connecté ;
///  - nouveau compte    : [onProfileRequired] ouvre le formulaire « Dernière étape » ;
///  - compte en attente : [onPending] affiche « Presque prêt ».
/// Toute erreur est affichée dans la carte (jamais d'échec silencieux).
class SocialButtons extends ConsumerStatefulWidget {
  const SocialButtons({super.key, required this.accent, required this.onProfileRequired, required this.onPending});

  final Color accent;
  final void Function(String idToken, Map<String, dynamic> data) onProfileRequired;
  final VoidCallback onPending;

  @override
  ConsumerState<SocialButtons> createState() => _SocialButtonsState();
}

class _SocialButtonsState extends ConsumerState<SocialButtons> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    String? idToken;
    try {
      idToken = await ref.read(socialAuthProvider).signInWithGoogle();
      await ref.read(authControllerProvider.notifier).signInSocial(idToken);
    } on SocialAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
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
    } catch (e) {
      if (mounted) setState(() => _error = 'Connexion Google impossible : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
          child: Text('ou', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        Expanded(child: Divider(color: Colors.white12)),
      ]),
      const SizedBox(height: 12),
      if (_error != null) AuthError(_error),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
            backgroundColor: Colors.white.withValues(alpha: 0.04),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _loading ? null : _signIn,
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _GoogleBadge(),
                  SizedBox(width: 10),
                  Text('Continuer avec Google', style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
        ),
      ),
    ]);
  }
}

/// « G » coloré (évite d'embarquer le logo officiel).
class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 14)),
      );
}
