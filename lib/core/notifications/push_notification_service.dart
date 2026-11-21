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

  /// Appelé à chaque notification reçue au premier plan (pour rafraîchir les listes).
  void Function()? onMessage;

  /// Initialise Firebase et les notifications locales. Renvoie false si Firebase n'est pas configuré.
  Future<bool> init() async {
    if (_ready) return true;
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await Firebase.initializeApp();
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

    // Notification reçue application ouverte : on l'affiche nous-mêmes.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
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
          payload: message.data['task_id'],
        );
      }
      _acknowledge(message);
      onMessage?.call();
    });

    // Clic sur une notification (appli en arrière-plan ou fermée).
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _openFromPayload(m.data['task_id']));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      scheduleMicrotask(() => _openFromPayload(initial.data['task_id']));
    }

    _ready = true;
    return true;
  }

  /// Demande l'autorisation (Android 13+) et envoie le jeton FCM à l'API.
  Future<void> registerDevice() async {
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

  /// Accusé « reçu » dès l'arrivée de la notification.
  void _acknowledge(RemoteMessage message) {
    final id = int.tryParse(message.data['task_id'] ?? '');
    if (id != null) {
      unawaited(_ref.read(taskRepositoryProvider).markDelivered([id]).catchError((_) {}));
    }
  }

  void _openFromPayload(String? payload) {
    final id = int.tryParse(payload ?? '');
    if (id != null) onOpenTask?.call(id);
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) => PushNotificationService(ref));
