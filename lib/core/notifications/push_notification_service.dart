import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';
import '../firebase/firebase_setup.dart';

/// Réception d'une notification quand l'application est fermée / en arrière-plan.
/// Doit être une fonction de premier niveau.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Notifications push (Firebase Cloud Messaging, Android).
///
/// - Firebase est facultatif : sans google-services.json, l'appli fonctionne
///   normalement, simplement sans notifications.
/// - Le serveur n'envoie une notification qu'aux membres concernés
///   (destinataires de la tâche) ; ici on l'affiche et on gère le clic.
class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;
  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  StreamSubscription<String>? _tokenSub;

  static const _channel = AndroidNotificationChannel(
    'ctech_tasks',
    'Tâches C-Tech',
    description: 'Nouvelles tâches adressées à votre département',
    importance: Importance.high,
  );

  /// Appelé quand l'utilisateur touche une notification : identifiant de la tâche.
  void Function(int taskId)? onOpenTask;

  /// Toucher une notification de message : ouvre la conversation.
  void Function(int conversationId)? onOpenConversation;

  /// Toucher une notification de demande d'inscription : ouvre la page Équipe.
  void Function()? onOpenApprovals;

  /// Chaque message reçu app ouverte (visible ou silencieux) : scope + données,
  /// pour rafraîchir en direct l'écran concerné (voir CountersController.onServerSignal).
  void Function(String scope, Map<String, dynamic> data)? onSignal;

  /// Web, onglet ouvert : afficher un bandeau dans l'appli (titre, texte, destination).
  void Function(String title, String body, String? payload)? onForegroundNotification;

  /// Ouvre la destination d'un bandeau web (même logique qu'une notification touchée).
  void open(String? payload) => _openFromPayload(payload);

  /// Notifications prises en charge : application Android et version web (navigateur).
  bool get _supported => kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  /// Plateforme envoyée au serveur avec le jeton (le web ne reçoit pas les signaux silencieux).
  String get _platform => kIsWeb ? 'web' : 'android';

  /// Jeton de l'appareil : sur le web, Firebase exige la clé « Web Push » (VAPID).
  Future<String?> _getToken() => kIsWeb
      ? FirebaseMessaging.instance.getToken(vapidKey: FirebaseSetup.webPushKey)
      : FirebaseMessaging.instance.getToken();

  /// Conversation actuellement affichée : pas de bannière pour ses nouveaux messages.
  int? activeConversationId;

  /// Initialise Firebase et les notifications locales. Renvoie false si Firebase n'est pas configuré.
  Future<bool> init() async {
    if (_ready) return true;
    if (!_supported) return false;
    if (!FirebaseSetup.ready) return false; // voir core/firebase/firebase_setup.dart

    if (!kIsWeb) {
      // Android : messages reçus appli fermée + notifications locales (appli ouverte).
      // Sur le web, c'est le fichier web/firebase-messaging-sw.js qui gère l'arrière-plan.
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      await _local.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (response) => _openFromPayload(response.payload),
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // Message reçu application ouverte.
    FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      final type = data['type'] as String?;

      // 1) Mise à jour en direct de l'écran concerné.
      final scope = switch (type) {
        'sync' => data['scope'] as String? ?? 'tasks',
        'task_created' => 'tasks',
        'approval_request' => 'approvals',
        'chat_message' => 'chat',
        _ => 'tasks',
      };
      onSignal?.call(scope, data);

      // 2) Bannière (sauf signal silencieux, ou message de la conversation ouverte).
      final notification = message.notification;
      final inOpenChat = type == 'chat_message' && '${data['conversation_id']}' == '$activeConversationId';
      if (notification != null && !inOpenChat && kIsWeb) {
        // Web, onglet ouvert : bandeau dans l'application (le navigateur n'affiche rien au premier plan).
        onForegroundNotification?.call(notification.title ?? 'C-Tech Tasks', notification.body ?? '', _payload(data));
      } else if (notification != null && !inOpenChat) {
        _local.show(
          message.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: _payload(data),
        );
      }
      _acknowledge(message);
    });

    // Clic sur une notification (appli en arrière-plan ou fermée).
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _openFromPayload(_payload(m.data)));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      scheduleMicrotask(() => _openFromPayload(_payload(initial.data)));
    }

    _ready = true;
    return true;
  }

  /// Demande l'autorisation (Android 13+) et envoie le jeton FCM à l'API.
  /// Ne fait rien si l'utilisateur a désactivé les notifications dans son profil.
  Future<void> registerDevice() async {
    if (_ref.read(cacheStorageProvider).getString('push_enabled') == 'false') return;
    if (!await init()) return;
    try {
      if (kIsWeb && FirebaseSetup.webPushKey.isEmpty) return; // clé Web Push pas encore fournie
      await FirebaseMessaging.instance.requestPermission();
      final token = await _getToken();
      final repo = _ref.read(authRepositoryProvider);
      await repo.updateFcmToken(token, platform: _platform);
      await _tokenSub?.cancel();
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) => repo.updateFcmToken(t, platform: _platform));
    } catch (e) {
      debugPrint('Enregistrement FCM impossible : $e');
    }
  }

  /// Diagnostic « Tester les notifications » (Profil › Compte) : vérifie chaque maillon
  /// de la chaîne et envoie une vraie notification de test via le serveur.
  Future<List<PushCheck>> diagnose() async {
    final checks = <PushCheck>[];

    // 1. Plateforme : application Android ou navigateur (Web Push).
    checks.add(PushCheck(kIsWeb ? 'Version web (navigateur)' : 'Application Android', _supported,
        _supported ? null : 'Les notifications fonctionnent sur l\'application Android et dans le navigateur, pas dans l\'application Windows.'));
    if (!_supported) return checks;
    if (kIsWeb) {
      final hasKey = FirebaseSetup.webPushKey.isNotEmpty;
      checks.add(PushCheck('Clé Web Push configurée', hasKey,
          hasKey ? null : 'La clé « Certificats Web Push » de Firebase n\'est pas encore dans l\'application.'));
      if (!hasKey) return checks;
    }

    // 2. Réglage de l'appli.
    final enabled = _ref.read(cacheStorageProvider).getString('push_enabled') != 'false';
    checks.add(PushCheck('Notifications activées dans le profil', enabled,
        enabled ? null : 'Activez l\'interrupteur « Notifications » ci-dessus.'));
    if (!enabled) return checks;

    // 3. Firebase sur le téléphone.
    final ready = await init();
    checks.add(PushCheck('Firebase démarré sur le téléphone', ready,
        ready ? null : (FirebaseSetup.error ?? 'Fichier google-services.json absent ou invalide.')));
    if (!ready) return checks;

    // 4. Autorisation Android.
    final settings = await FirebaseMessaging.instance.requestPermission();
    final allowed = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    checks.add(PushCheck('Autorisation du téléphone', allowed,
        allowed
            ? null
            : kIsWeb
                ? 'Autorisez les notifications pour ce site (icône à gauche de l\'adresse › Notifications › Autoriser).'
                : 'Autorisez les notifications : Paramètres du téléphone › Applications › C-Tech Tasks › Notifications.'));
    if (!allowed) return checks;

    // 5. Jeton de l'appareil envoyé au serveur.
    String? token;
    try {
      token = await _getToken();
      await _ref.read(authRepositoryProvider).updateFcmToken(token, platform: _platform);
    } catch (e) {
      checks.add(PushCheck('Appareil enregistré auprès du serveur', false, 'Impossible d\'obtenir ou d\'envoyer le jeton : $e'));
      return checks;
    }
    checks.add(PushCheck('Appareil enregistré auprès du serveur', token != null,
        token == null ? 'Firebase n\'a pas fourni de jeton (Google Play Services absent ?).' : null));
    if (token == null) return checks;

    // 6. Le serveur envoie une vraie notification.
    try {
      final r = await _ref.read(apiClientProvider).post('/auth/push-test') as Map<String, dynamic>;
      final configured = r['configured'] == true;
      checks.add(PushCheck('Firebase configuré sur le serveur', configured,
          configured ? null : 'Sur Railway, ajoutez FIREBASE_CREDENTIALS_JSON et FIREBASE_PROJECT_ID=task-ctech, puis redéployez.'));
      if (configured) {
        final sent = r['sent'] == true;
        checks.add(PushCheck('Notification de test envoyée', sent,
            sent ? 'Elle doit apparaître dans quelques secondes.' : _explain('${r['reason'] ?? ''}')));
      }
    } catch (e) {
      checks.add(PushCheck('Serveur joignable', false, '$e'));
    }
    return checks;
  }

  /// Traduit la raison renvoyée par le serveur en conseil compréhensible.
  String _explain(String reason) {
    if (reason.contains('SENDER_ID_MISMATCH') || reason.contains('PERMISSION_DENIED')) {
      return 'Le serveur et l\'application n\'utilisent pas le même projet Firebase (vérifiez FIREBASE_PROJECT_ID=task-ctech et la clé du compte de service).';
    }
    if (reason.contains('UNREGISTERED') || reason.contains('INVALID_ARGUMENT')) {
      return 'Le jeton de cet appareil n\'est plus valide : fermez et rouvrez l\'application puis réessayez.';
    }
    if (reason.contains('UNREACHABLE')) return 'Le serveur n\'arrive pas à joindre Firebase : $reason';
    return 'Refus de Firebase : $reason';
  }

  /// Désactive les notifications : le serveur oublie le jeton de ce téléphone.
  Future<void> unregisterDevice() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
    await _ref.read(authRepositoryProvider).updateFcmToken(null);
  }

  /// Accusé « reçu » dès l'arrivée de la notification.
  void _acknowledge(RemoteMessage message) {
    if (message.data['type'] != 'task_created') return;
    final id = int.tryParse('${message.data['task_id'] ?? ''}');
    if (id != null) {
      unawaited(_ref.read(taskRepositoryProvider).markDelivered([id]).catchError((_) {}));
    }
  }

  /// Encode la destination d'une notification : « task:12 », « chat:3 », « approvals ».
  String? _payload(Map<String, dynamic> data) => switch (data['type']) {
        'task_created' => 'task:${data['task_id']}',
        'chat_message' => 'chat:${data['conversation_id']}',
        'approval_request' => 'approvals',
        _ => null,
      };

  /// Ouvre l'écran correspondant à une notification touchée.
  void _openFromPayload(String? payload) {
    if (payload == null) return;
    final parts = payload.split(':');
    final id = parts.length > 1 ? int.tryParse(parts[1]) : null;
    switch (parts.first) {
      case 'task' when id != null:
        onOpenTask?.call(id);
      case 'chat' when id != null:
        onOpenConversation?.call(id);
      case 'approvals':
        onOpenApprovals?.call();
    }
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) => PushNotificationService(ref));

/// Une étape du diagnostic des notifications.
class PushCheck {
  const PushCheck(this.label, this.ok, [this.detail]);
  final String label;
  final bool ok;

  /// Conseil (si échec) ou précision (si réussite).
  final String? detail;
}
