import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/push_notification_service.dart';
import '../data/models/user.dart';
import 'core_providers.dart';
import 'data_providers.dart';

/// État d'authentification de l'application.
enum AuthStatus { unknown, signedOut, signedIn }

class AuthState {
  const AuthState(this.status, [this.user]);
  final AuthStatus status;
  final AppUser? user;
}

/// Contrôleur de session :
///  - au démarrage, restaure le jeton chiffré (si « Se souvenir de moi ») ;
///  - connexion / déconnexion ;
///  - déconnexion automatique si l'API répond 401 (jeton expiré après 7 semaines).
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.read(apiClientProvider).onUnauthorized = () => unawaited(signOut(remote: false));
    unawaited(_restore());
    return const AuthState(AuthStatus.unknown);
  }

  Future<void> _restore() async {
    final repo = ref.read(authRepositoryProvider);
    final token = await repo.readStoredToken();
    if (token == null) {
      state = const AuthState(AuthStatus.signedOut);
      return;
    }
    ref.read(tokenHolderProvider).token = token;
    try {
      final user = await repo.me();
      state = AuthState(AuthStatus.signedIn, user);
      unawaited(ref.read(pushNotificationServiceProvider).registerDevice());
    } catch (_) {
      await signOut(remote: false);
    }
  }

  /// Connexion ; les erreurs (ApiException) remontent au formulaire.
  Future<void> signIn(String email, String password, {required bool remember}) async {
    final session = await ref.read(authRepositoryProvider).login(email, password, remember: remember);
    ref.read(tokenHolderProvider).token = session.token;
    state = AuthState(AuthStatus.signedIn, session.user);
    unawaited(ref.read(pushNotificationServiceProvider).registerDevice());
  }

  /// Connexion Google : [idToken] Firebase + profil (seulement pour un nouveau compte).
  /// Les erreurs (PROFILE_REQUIRED, ACCOUNT_PENDING...) remontent à l'écran sous forme d'ApiException.
  Future<void> signInSocial(
    String idToken, {
    String? firstName,
    String? lastName,
    int? departmentId,
    String? position,
    bool? acceptTerms,
  }) async {
    final session = await ref.read(authRepositoryProvider).social(
          idToken,
          firstName: firstName,
          lastName: lastName,
          departmentId: departmentId,
          position: position,
          acceptTerms: acceptTerms,
        );
    ref.read(tokenHolderProvider).token = session.token;
    state = AuthState(AuthStatus.signedIn, session.user);
    unawaited(ref.read(pushNotificationServiceProvider).registerDevice());
  }

  /// Recharge le profil (après validation d'un compte, par exemple).
  Future<void> refreshUser() async {
    final user = await ref.read(authRepositoryProvider).me();
    state = AuthState(AuthStatus.signedIn, user);
  }

  /// Remet l'application « à neuf » pour le prochain utilisateur :
  ///  - on revient sur l'onglet « Reçues » (et non sur le Profil, d'où l'on s'est déconnecté) ;
  ///  - on oublie les listes, pastilles, messages et filtres de la personne précédente.
  void _resetSession() {
    ref.invalidate(homeSectionProvider);
    ref.invalidate(teamTabProvider);
    ref.invalidate(memberDepartmentFilterProvider);
    ref.invalidate(countersProvider);
    ref.invalidate(taskListProvider);
    ref.invalidate(conversationsProvider);
    ref.invalidate(approvalsProvider);
    ref.invalidate(membersProvider);
    ref.invalidate(departmentsOverviewProvider);
  }

  Future<void> signOut({bool remote = true}) async {
    final repo = ref.read(authRepositoryProvider);
    if (remote) {
      await repo.logout();
    } else {
      await repo.clearLocal();
    }
    ref.read(tokenHolderProvider).token = null;
    unawaited(ref.read(socialAuthProvider).signOut());
    _resetSession();
    state = const AuthState(AuthStatus.signedOut);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Raccourci : utilisateur connecté (null sinon).
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider).user);
