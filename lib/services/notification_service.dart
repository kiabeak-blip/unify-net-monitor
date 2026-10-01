// lib/services/notification_service.dart
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/device.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Collision-free notification ID from last two octets + type offset (0=down, 1=up)
  static int _notifId(String ip, int type) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      final c = int.tryParse(parts[2]) ?? 0;
      final d = int.tryParse(parts[3]) ?? 0;
      return c * 256 + d + type * 65536;
    }
    return ip.hashCode.abs() + type * 65536;
  }

  /// Notifications are only supported on Android, iOS, and macOS.
  static bool get _supported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  static Future<void> init() async {
    if (!_supported || _initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    if (!_supported) return;

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> notifyDeviceDown(Device device) async {
    if (!_supported || !_initialized) return;
    await _plugin.show(
      _notifId(device.ip, 0),
      '⚠️ Device Offline',
      '${device.name} (${device.ip}) is no longer reachable',
      _buildDetails(color: const Color(0xFFFF4444)),
    );
  }

  static Future<void> notifyDeviceUp(Device device) async {
    if (!_supported || !_initialized) return;
    await _plugin.show(
      _notifId(device.ip, 1),
      '✅ Device Back Online',
      '${device.name} (${device.ip}) is reachable again',
      _buildDetails(color: const Color(0xFF44FF88)),
    );
  }

  static Future<void> notifyScanComplete(int found, int online) async {
    if (!_supported || !_initialized) return;
    await _plugin.show(
      99999,
      '🔍 Scan Complete',
      'Found $found devices — $online online',
      _buildDetails(),
    );
  }

  static NotificationDetails _buildDetails({Color? color}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'network_monitor',
        'Network Monitor',
        channelDescription: 'Alerts for device status changes',
        importance: Importance.high,
        priority: Priority.high,
        color: color,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
