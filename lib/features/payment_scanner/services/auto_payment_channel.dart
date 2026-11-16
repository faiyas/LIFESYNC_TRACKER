import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AutoPaymentChannel {
  static final AutoPaymentChannel instance = AutoPaymentChannel._internal();
  AutoPaymentChannel._internal();

  static const MethodChannel _channel = MethodChannel('com.lifesync.tracker/auto_payment');

  void Function(Map<String, dynamic> notification)? onNotificationReceived;
  void Function(Map<String, dynamic> sms)? onSmsReceived;

  bool _initialized = false;

  void initialize() {
    if (_initialized || !Platform.isAndroid) return;
    _channel.setMethodCallHandler(_handleMethodCall);
    _initialized = true;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationReceived':
        if (call.arguments is Map) {
          final map = Map<String, dynamic>.from(call.arguments as Map);
          onNotificationReceived?.call(map);
        }
        break;
      case 'onSmsReceived':
        if (call.arguments is Map) {
          final map = Map<String, dynamic>.from(call.arguments as Map);
          onSmsReceived?.call(map);
        }
        break;
      default:
        debugPrint('Unhandled AutoPaymentChannel method: ${call.method}');
    }
  }

  /// Check whether SMS read/receive permissions are granted
  Future<bool> checkSmsPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('checkSmsPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('Error checking SMS permission: $e');
      return false;
    }
  }

  /// Request SMS permissions
  Future<bool> requestSmsPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('requestSmsPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('Error requesting SMS permission: $e');
      return false;
    }
  }

  /// Check whether Android Notification Listener Service is enabled by the user
  Future<bool> isNotificationListenerEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isNotificationListenerEnabled');
      return res ?? false;
    } catch (e) {
      debugPrint('Error checking notification listener status: $e');
      return false;
    }
  }

  /// Open Android Notification Access settings so user can toggle LifeSync
  Future<void> openNotificationListenerSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openNotificationListenerSettings');
    } catch (e) {
      debugPrint('Error opening notification settings: $e');
    }
  }

  /// Query recent SMS messages since a timestamp
  Future<List<Map<String, dynamic>>> readRecentSms({int sinceTimestamp = 0, int limit = 30}) async {
    if (!Platform.isAndroid) return [];
    try {
      final res = await _channel.invokeListMethod<Map>('readRecentSms', {
        'sinceTimestamp': sinceTimestamp,
        'limit': limit,
      });
      if (res == null) return [];
      return res.map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (e) {
      debugPrint('Error reading recent SMS: $e');
      return [];
    }
  }

  /// Retrieve and clear any payment notifications caught in the native buffer
  Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    if (!Platform.isAndroid) return [];
    try {
      final res = await _channel.invokeListMethod<Map>('getPendingNotifications');
      if (res == null) return [];
      return res.map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (e) {
      debugPrint('Error getting pending notifications: $e');
      return [];
    }
  }

  /// Retrieve and clear any SMS caught in the native receiver buffer
  Future<List<Map<String, dynamic>>> getPendingSms() async {
    if (!Platform.isAndroid) return [];
    try {
      final res = await _channel.invokeListMethod<Map>('getPendingSms');
      if (res == null) return [];
      return res.map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (e) {
      debugPrint('Error getting pending SMS: $e');
      return [];
    }
  }

  /// Fetch recent screenshots saved in device
  Future<List<Map<String, dynamic>>> getRecentScreenshots({int sinceTimestamp = 0, int limit = 20}) async {
    if (!Platform.isAndroid) return [];
    try {
      final res = await _channel.invokeListMethod<Map>('getRecentScreenshots', {
        'sinceTimestamp': sinceTimestamp,
        'limit': limit,
      });
      if (res == null) return [];
      return res.map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (e) {
      debugPrint('Error getting recent screenshots: $e');
      return [];
    }
  }
}

