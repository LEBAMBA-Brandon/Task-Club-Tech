import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';

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

  /// Conversation actuellement affichée : pas de bannière pour ses nouveaux messages.
  int? activeConversationId;

  /// Initialise Firebase et les notifications locales. Renvoie false si Firebase n'est pas configuré.
  Future<bool> init() async {
    if (_ready) return true;
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase non configuré (google-services.json absent) : $e');
      return false;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    await _local.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) => _openFromPayload(response.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

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
      if (notification != null && !inOpenChat) {
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
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      final repo = _ref.read(authRepositoryProvider);
      await repo.updateFcmToken(token);
      await _tokenSub?.cancel();
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) => repo.updateFcmToken(t));
    } catch (e) {
      debugPrint('Enregistrement FCM impossible : $e');
    }
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
