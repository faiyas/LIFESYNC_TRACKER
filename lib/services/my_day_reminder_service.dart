import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../models/my_day_models.dart';
import 'app_time_service.dart';
import 'notification_service.dart';

/// Service managing timezone-safe local notifications and smart missed alerts for My Day tasks
class MyDayReminderService {
  static final MyDayReminderService instance = MyDayReminderService._init();

  MyDayReminderService._init();

  /// Schedule all enabled reminders for a task
  Future<void> scheduleTaskReminders(MyDayTask task) async {
    if (task.startTime == null || task.isCompleted) return;

    try {
      final taskDate = DateTime.tryParse(task.date) ?? DateTime.now();
      final startDateTime = AppTimeService.parseTimeToDateTime(taskDate, task.startTime!);
      final now = DateTime.now();

      final baseId = task.id.hashCode.abs() % 1000000;

      // 1. Advance Reminder (e.g. 15m before)
      if (task.reminderBeforeMinutes != null && task.reminderBeforeMinutes! > 0) {
        final advanceTime = startDateTime.subtract(Duration(minutes: task.reminderBeforeMinutes!));
        if (advanceTime.isAfter(now)) {
          final title = '⏰ Upcoming: ${task.title}';
          final body = '${task.title} starts in ${task.reminderBeforeMinutes} minutes (${task.startTime}).';

          await NotificationService.instance.scheduleNotification(
            id: baseId + 1,
            title: title,
            body: body,
            scheduledDateTime: advanceTime,
            channelId: 'lifesync_reminders',
            channelName: 'LifeSync Reminders & Alerts',
            payload: 'my_day_task:${task.id}:advance',
          );
        }
      }

      // 2. Exact Start Reminder
      if (task.reminderAtStart) {
        if (startDateTime.isAfter(now)) {
          final title = '🚀 Starting Now: ${task.title}';
          final body = 'Time to begin ${task.title} (${task.startTime} - ${task.endTime ?? ''}).';

          await NotificationService.instance.scheduleNotification(
            id: baseId + 2,
            title: title,
            body: body,
            scheduledDateTime: startDateTime,
            channelId: 'lifesync_reminders',
            channelName: 'LifeSync Reminders & Alerts',
            payload: 'my_day_task:${task.id}:start',
          );
        }
      }

      // 3. Missed Task Check Reminder at End Time
      if (task.endTime != null) {
        final endDateTime = AppTimeService.parseTimeToDateTime(taskDate, task.endTime!);
        if (endDateTime.isAfter(now)) {
          final title = '⚠️ Checkpoint: ${task.title}';
          final body = 'Did you finish ${task.title}? Tap to mark complete, reschedule, or move to next slot.';

          await NotificationService.instance.scheduleNotification(
            id: baseId + 3,
            title: title,
            body: body,
            scheduledDateTime: endDateTime,
            channelId: 'lifesync_reminders',
            channelName: 'LifeSync Reminders & Alerts',
            payload: 'my_day_task:${task.id}:missed',
          );
        }
      }
    } catch (e) {
      debugPrint('Error scheduling task reminders for ${task.title}: $e');
    }
  }

  /// Cancel reminders for a task
  Future<void> cancelTaskReminders(String taskId) async {
    final baseId = taskId.hashCode.abs() % 1000000;
    await NotificationService.instance.cancelNotification(baseId + 1);
    await NotificationService.instance.cancelNotification(baseId + 2);
    await NotificationService.instance.cancelNotification(baseId + 3);
  }

  /// Reschedule all active reminders on app launch or date change
  Future<void> rescheduleAllUpcomingReminders() async {
    try {
      final db = await AppDatabase.instance.database;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final records = await db.query(
        'my_day_tasks',
        where: 'isCompleted = 0 AND (date >= ? OR recurrenceRule != "none")',
        whereArgs: [todayStr],
      );

      for (final r in records) {
        final task = MyDayTask.fromMap(r);
        await scheduleTaskReminders(task);
      }
    } catch (e) {
      debugPrint('Error rescheduling upcoming My Day reminders: $e');
    }
  }
}
