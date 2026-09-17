import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationType {
  transactionSuccess,
  transactionFailed,
  yieldClaimable,
  priceAlert,
  invoiceMaturity,
  newListing,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
    'read': read,
  };

  static AppNotification fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => NotificationType.transactionSuccess,
      ),
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      read: json['read'] as bool? ?? false,
    );
  }
}

class NotificationService {
  static const _storageKey = 'app_notifications';
  static const _maxNotifications = 100;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    );
    try {
      await _local.initialize(settings: settings);
      _initialized = true;
    } catch (_) {
      // Persistence still works when a platform cannot show notifications.
    }
  }

  Future<void> notify({
    required NotificationType type,
    required String title,
    required String body,
  }) async {
    await _store(type: type, title: title, body: body);
    await initialize();
    if (!_initialized) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'aeroreal_main',
        'Aeroreal',
        channelDescription: 'Aeroreal notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
    );
    try {
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {
      // Do not make a completed transaction fail because a notification failed.
    }
  }

  Future<void> _store({
    required NotificationType type,
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    raw.insert(
      0,
      jsonEncode(
        AppNotification(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          type: type,
          title: title,
          body: body,
          timestamp: DateTime.now(),
        ).toJson(),
      ),
    );
    if (raw.length > _maxNotifications) {
      raw.removeRange(_maxNotifications, raw.length);
    }
    await prefs.setStringList(_storageKey, raw);
  }

  Future<List<AppNotification>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_storageKey) ?? [])
        .map(
          (value) => AppNotification.fromJson(
            jsonDecode(value) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<int> getUnreadCount() async {
    return (await getAll()).where((notification) => !notification.read).length;
  }

  Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final updated = (prefs.getStringList(_storageKey) ?? []).map((value) {
      final json = jsonDecode(value) as Map<String, dynamic>;
      json['read'] = true;
      return jsonEncode(json);
    }).toList();
    await prefs.setStringList(_storageKey, updated);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
