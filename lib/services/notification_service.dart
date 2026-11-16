import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  NotificationService._init();

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      tz.initializeTimeZones();
      final offset = DateTime.now().timeZoneOffset;
      final tzName = DateTime.now().timeZoneName;

      tz.Location? matchedLocation;
      try {
        for (final loc in tz.timeZoneDatabase.locations.values) {
          if (loc.currentTimeZone.offset == offset.inMilliseconds) {
            matchedLocation = loc;
            break;
          }
        }
      } catch (_) {}

      if (matchedLocation != null) {
        tz.setLocalLocation(matchedLocation);
      } else {
        final customTz = tz.TimeZone(offset.inMilliseconds, isDst: false, abbreviation: tzName);
        final customLoc = tz.Location('DeviceLocal', [0], [0], [customTz]);
        tz.setLocalLocation(customLoc);
      }

      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification tapped with payload: ${response.payload}');
        },
      );

      // Request runtime notification permission and create channels for Android
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'lifesync_reminders',
            'LifeSync Reminders & Alerts',
            description: 'Push notifications for expenses, tasks, trips, and custom reminders',
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
          ),
        );
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'lifesync_finance_summary',
            'Daily Financial Summary',
            description: 'Nightly push summary of spent, income, and overall balance at 11:00 PM',
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
          ),
        );
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'lifesync_task_reminders',
            'Pending Task Reminders',
            description: 'Periodic 6-hour checkpoint reminders for incomplete tasks',
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
          ),
        );

        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Explicitly prompt user for notification & exact alarm permissions
  Future<bool> requestPermissions() async {
    try {
      final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission() ?? false;
        await androidImpl.requestExactAlarmsPermission();
        return granted;
      }
      final iosImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImpl != null) {
        final granted = await iosImpl.requestPermissions(alert: true, badge: true, sound: true) ?? false;
        return granted;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return true;
  }

  /// Check if notification permissions are enabled
  Future<bool> arePermissionsGranted() async {
    try {
      final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final enabled = await androidImpl.areNotificationsEnabled() ?? false;
        return enabled;
      }
    } catch (e) {
      debugPrint('Error checking notification permissions: $e');
    }
    return true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? channelId,
    String? channelName,
    String? channelDescription,
    String? payload,
  }) async {
    if (!_isInitialized) await init();
    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId ?? 'lifesync_reminders',
        channelName ?? 'LifeSync Reminders & Alerts',
        channelDescription: channelDescription ?? 'Push notifications for expenses, tasks, trips, and custom reminders',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: channelName ?? 'LifeSync Tracker',
        ),
      );

      final NotificationDetails details = NotificationDetails(android: androidDetails);
      await _notificationsPlugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? channelId,
    String? channelName,
    String? channelDescription,
    String? payload,
  }) async {
    if (!_isInitialized) await init();
    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId ?? 'lifesync_reminders',
        channelName ?? 'LifeSync Reminders & Alerts',
        channelDescription: channelDescription ?? 'Push notifications for expenses, tasks, trips, and custom reminders',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: channelName ?? 'LifeSync Tracker',
        ),
      );

      final NotificationDetails details = NotificationDetails(android: androidDetails);
      final tz.TZDateTime tzDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

      if (tzDateTime.isAfter(tz.TZDateTime.now(tz.local))) {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzDateTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } else {
        await _notificationsPlugin.show(id, title, body, details, payload: payload);
      }
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      await showNotification(
        id: id,
        title: title,
        body: body,
        channelId: channelId,
        channelName: channelName,
        payload: payload,
      );
    }
  }

  /// Schedule a daily recurring notification at a specific hour and minute
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? channelId,
    String? channelName,
    String? channelDescription,
    String? payload,
  }) async {
    if (!_isInitialized) await init();
    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId ?? 'lifesync_finance_summary',
        channelName ?? 'Daily Financial Summary',
        channelDescription: channelDescription ?? 'Nightly push summary of spent, income, and balance',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Financial Summary',
        ),
      );

      final NotificationDetails details = NotificationDetails(android: androidDetails);
      final nowLocal = DateTime.now();
      var scheduledDateLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, hour, minute);
      if (scheduledDateLocal.isBefore(nowLocal)) {
        scheduledDateLocal = scheduledDateLocal.add(const Duration(days: 1));
      }
      final scheduledDate = tz.TZDateTime.from(scheduledDateLocal, tz.local);

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      debugPrint('Successfully scheduled daily notification #$id for $hour:$minute (Next: $scheduledDate)');
    } catch (e) {
      debugPrint('Error scheduling daily notification: $e');
    }
  }

  /// Helper to schedule trip push notification reminder
  Future<void> scheduleTripNotification({
    required String tripId,
    required String tripTitle,
    required String destination,
    required DateTime scheduledDateTime,
    String? customMessage,
  }) async {
    final notifId = tripId.hashCode.abs() % 100000;
    final title = '✈️ Upcoming Trip: $tripTitle';
    final body = customMessage != null && customMessage.trim().isNotEmpty
        ? customMessage.trim()
        : 'Get ready for your trip to $destination! Check packing and itinerary.';

    await scheduleNotification(
      id: notifId,
      title: title,
      body: body,
      scheduledDateTime: scheduledDateTime,
    );
  }

  /// Cancel notification by ID
  Future<void> cancelNotification(int id) async {
    if (!_isInitialized) await init();
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }
}
