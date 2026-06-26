import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'agent_client.dart';
import 'vault.dart';

// ============================================================
// AlertsRelay — push notifications gateway
// ============================================================
// The relay handles three independent flows:
//
//   1) Cold start — app was killed when push arrived.  Firebase
//      surfaces it via `getInitialMessage()`; we STASH the URL
//      so the next IgnitionStage launch can route directly to
//      it instead of doing the usual verdict roundtrip.
//
//   2) Warm background — app was alive but backgrounded.  The
//      URL is delivered via the `onLandingPush` callback so the
//      Portal can swap in-place; it is NOT persisted.
//
//   3) Foreground — Firebase delivers via `onMessage`; we use
//      flutter_local_notifications to surface a heads-up
//      banner (with optional big picture).  Tapping that
//      banner triggers the same `onLandingPush` callback.
//
// `_channelId` MUST match the value declared in AndroidManifest
// as `default_notification_channel_id`.
// ============================================================

const String _channelId = 'magma_blitz_flame_channel';
const String _channelName = 'Magma Blitz Alerts';
const String _notificationIcon = '@drawable/ic_magma_flame';

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // OS handles the system tray on its own.  Avoid touching UI
  // here — this runs in a separate isolate.
}

class AlertsRelay {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final Vault _vault;

  FirebaseMessaging? _fcm;
  String? _token;
  bool _initialized = false;

  AlertsRelay(this._vault);

  void Function(String landingUrl)? onLandingPush;
  void Function(String fcmToken)? onTokenRotated;

  String? get token => _token;

  Future<void> ignite() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      _fcm = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

      await _wireLocalNotifications();

      _token = await _fcm!.getToken();
      _fcm!.onTokenRefresh.listen((next) {
        _token = next;
        onTokenRotated?.call(next);
      });

      FirebaseMessaging.onMessage.listen(_handleForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleWarmTap);

      final initial = await _fcm!.getInitialMessage();
      if (initial != null) await _handleColdStart(initial);

      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AlertsRelay] init error: $e');
    }
  }

  Future<void> _wireLocalNotifications() async {
    const androidInit =
        AndroidInitializationSettings(_notificationIcon);
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload) as Map<String, dynamic>;
          final url = decoded['url'] as String?;
          if (url != null && url.isNotEmpty) onLandingPush?.call(url);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Heads-up notifications for Magma Blitz',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Asks the OS for push permission (Android 13+ requires it).
  /// Records the OS-denied flag so we never re-prompt after a
  /// hard rejection.
  Future<bool> requestPermission() async {
    if (_fcm == null) return false;
    final settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final status = settings.authorizationStatus;
    final granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    await _vault.markAlertsGranted(granted);
    if (!granted && status == AuthorizationStatus.denied) {
      await _vault.markAlertsOsDenied();
    }
    return granted;
  }

  Future<void> _handleForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    if (!Platform.isAndroid) return;

    final imageUrl = notification.android?.imageUrl;
    AndroidNotificationDetails? details;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final bytes = await _downloadImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _notificationIcon,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _notificationIcon,
    );

    final payload =
        message.data.isNotEmpty ? jsonEncode(message.data) : null;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: details),
      payload: payload,
    );
  }

  void _handleWarmTap(RemoteMessage message) {
    final url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) onLandingPush?.call(url);
  }

  Future<void> _handleColdStart(RemoteMessage message) async {
    final url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      await _vault.stashPushUrl(url);
    }
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final response = await agentClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }
}
