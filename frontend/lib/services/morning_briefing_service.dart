import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class MorningBriefingNotifier {
  Future<void> send({
    required String message,
    required String languageCode,
  });
}

class LocalMorningBriefingNotifier implements MorningBriefingNotifier {
  LocalMorningBriefingNotifier({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> _initialize() async {
    if (_initialized) return;
    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        web: WebInitializationSettings(),
      ),
    );
    if (initialized != true) {
      throw const MorningBriefingException();
    }
    _initialized = true;
  }

  @override
  Future<void> send({
    required String message,
    required String languageCode,
  }) async {
    await _initialize();
    final granted = await _requestPermission();
    if (granted != true) throw const MorningBriefingException();
    await _plugin.show(
      id: 1,
      title: languageCode == 'ru' ? 'RunCoach AI' : 'RunCoach AI',
      body: message,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'runcoach_morning_briefings',
          'Morning briefings',
          channelDescription: 'Personalized running and weather briefings',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        web: WebNotificationDetails(),
      ),
    );
  }

  Future<bool?> _requestPermission() async {
    if (kIsWeb) {
      return _plugin
          .resolvePlatformSpecificImplementation<
              WebFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    final androidPermission = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final iosPermission = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return androidPermission ?? iosPermission ?? true;
  }
}

class MorningBriefingException implements Exception {
  const MorningBriefingException();
}
