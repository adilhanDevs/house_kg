import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_coordinator.dart';
import 'push_permission.dart';

@pragma('vm:entry-point')
Future<void> firebasePushBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  // Notification is already in the backend DB. Android presents the alert.
}

class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging._(this._messaging, this._preferences);
  final FirebaseMessaging _messaging;
  final SharedPreferences _preferences;

  static Future<PushMessaging?> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp().timeout(const Duration(seconds: 10));
      }
      FirebaseMessaging.onBackgroundMessage(firebasePushBackgroundHandler);
      return FirebasePushMessaging._(
        FirebaseMessaging.instance,
        await SharedPreferences.getInstance(),
      );
    } catch (_) {
      debugPrint(
        'Push initialization unavailable; application remains usable.',
      );
      return null;
    }
  }

  @override
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;
  @override
  Stream<Map<String, dynamic>> get taps =>
      FirebaseMessaging.onMessageOpenedApp.map((message) => message.data);
  @override
  Stream<Map<String, dynamic>> get foreground =>
      FirebaseMessaging.onMessage.map((message) => message.data);
  @override
  Future<Map<String, dynamic>?> initialMessage() async =>
      (await _messaging.getInitialMessage())?.data;

  @override
  Future<bool> permission() => requestPushPermissionOnce(
    isAuthorized: () async =>
        _authorized(await _messaging.getNotificationSettings()),
    wasRequested: () =>
        _preferences.getBool('push_permission_requested') ?? false,
    markRequested: () async {
      await _preferences.setBool('push_permission_requested', true);
    },
    request: () async => _authorized(await _messaging.requestPermission()),
  );

  static bool _authorized(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  @override
  Future<String?> token() =>
      _messaging.getToken().timeout(const Duration(seconds: 10));
  @override
  Future<void> deleteToken() =>
      _messaging.deleteToken().timeout(const Duration(seconds: 10));
}
