import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import 'notification_service.dart';
import 'my_day_reminder_service.dart';

class FinancialDailySummaryData {
  final double todaySpent;
  final double todayIncome;
  final double overallBalance;

  FinancialDailySummaryData({
    required this.todaySpent,
    required this.todayIncome,
    required this.overallBalance,
  });
}

class AppNotificationScheduler {
  static final AppNotificationScheduler instance = AppNotificationScheduler._init();

  AppNotificationScheduler._init();

  static const int dailyFinanceSummaryNotifId = 110023; // 11:00 PM Summary ID
  static const List<int> taskReminderNotifIds = [6001, 6002, 6003, 6004]; // 6h intervals (6 AM, 12 PM, 6 PM, 12 AM)

  /// Initialize all recurring schedules
  Future<void> initAllScheduledNotifications() async {
    try {
      await NotificationService.instance.init();
      await scheduleDailyFinancialSummary();
      await schedulePeriodicTaskReminders();
      await MyDayReminderService.instance.rescheduleAllUpcomingReminders();
    } catch (e) {
      debugPrint('Error in initAllScheduledNotifications: $e');
    }
  }

  /// Calculates today's spent, today's income, and overall net balance from SQLite database
  Future<FinancialDailySummaryData> calculateFinancialSummary() async {
    final db = await AppDatabase.instance.database;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 1. Today's General Expenses
    double todaySpent = 0.0;
    try {
      final todayExpRes = await db.rawQuery(
        'SELECT SUM(amount) as total FROM expenses WHERE date = ?',
        [todayStr],
      );
      if (todayExpRes.isNotEmpty && todayExpRes.first['total'] != null) {
        todaySpent += (todayExpRes.first['total'] as num).toDouble();
      }
    } catch (_) {}

    // Today's Trip Expenses
    try {
      final todayTripRes = await db.rawQuery(
        'SELECT SUM(amount) as total FROM trip_expenses WHERE date = ?',
        [todayStr],
      );
      if (todayTripRes.isNotEmpty && todayTripRes.first['total'] != null) {
        todaySpent += (todayTripRes.first['total'] as num).toDouble();
      }
    } catch (_) {}

    // 2. Today's Income
    double todayIncome = 0.0;
    try {
      final todayIncRes = await db.rawQuery(
        'SELECT SUM(amount) as total FROM income WHERE date = ?',
        [todayStr],
      );
      if (todayIncRes.isNotEmpty && todayIncRes.first['total'] != null) {
        todayIncome = (todayIncRes.first['total'] as num).toDouble();
      }
    } catch (_) {}

    // 3. Overall Net Balance
    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    double unpaidBills = 0.0;
    double lentMoney = 0.0;
    double borrowedMoney = 0.0;
    double savedMoney = 0.0;
    double customerReceivables = 0.0;

    try {
      final incQ = await db.rawQuery('SELECT SUM(amount) as total FROM income');
      if (incQ.isNotEmpty && incQ.first['total'] != null) {
        totalIncome = (incQ.first['total'] as num).toDouble();
      }

      final expQ = await db.rawQuery('SELECT SUM(amount) as total FROM expenses');
      if (expQ.isNotEmpty && expQ.first['total'] != null) {
        totalExpenses += (expQ.first['total'] as num).toDouble();
      }

      final tripExpQ = await db.rawQuery('SELECT SUM(amount) as total FROM trip_expenses');
      if (tripExpQ.isNotEmpty && tripExpQ.first['total'] != null) {
        totalExpenses += (tripExpQ.first['total'] as num).toDouble();
      }

      final billsQ = await db.rawQuery('SELECT SUM(amount) as total FROM bills WHERE isPaid = 0');
      if (billsQ.isNotEmpty && billsQ.first['total'] != null) {
        unpaidBills = (billsQ.first['total'] as num).toDouble();
      }

      final lentQ = await db.rawQuery("SELECT SUM(amount) as total FROM borrowed_money WHERE type = 'lent' AND status != 'paid'");
      if (lentQ.isNotEmpty && lentQ.first['total'] != null) {
        lentMoney = (lentQ.first['total'] as num).toDouble();
      }

      final borrowedQ = await db.rawQuery("SELECT SUM(amount) as total FROM borrowed_money WHERE type = 'borrowed' AND status != 'paid'");
      if (borrowedQ.isNotEmpty && borrowedQ.first['total'] != null) {
        borrowedMoney = (borrowedQ.first['total'] as num).toDouble();
      }

      final savQ = await db.rawQuery('SELECT SUM(currentAmount) as total FROM savings_goals');
      if (savQ.isNotEmpty && savQ.first['total'] != null) {
        savedMoney = (savQ.first['total'] as num).toDouble();
      }

      // Customer Receivables from jobs & pending payments
      final jobQ = await db.rawQuery("SELECT SUM(pendingAmount) as total FROM customer_jobs WHERE status != 'completed'");
      if (jobQ.isNotEmpty && jobQ.first['total'] != null) {
        customerReceivables += (jobQ.first['total'] as num).toDouble();
      }

      try {
        final pendingPayQ = await db.rawQuery("SELECT SUM(remainingAmount) as total FROM pending_payments WHERE status != 'paid'");
        if (pendingPayQ.isNotEmpty && pendingPayQ.first['total'] != null) {
          customerReceivables += (pendingPayQ.first['total'] as num).toDouble();
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error calculating overall balance: $e');
    }

    final overallBalance = totalIncome - totalExpenses - unpaidBills + lentMoney - borrowedMoney - savedMoney + customerReceivables;

    return FinancialDailySummaryData(
      todaySpent: todaySpent,
      todayIncome: todayIncome,
      overallBalance: overallBalance,
    );
  }

  /// Schedule the Nightly 11:00 PM (23:00) Financial Summary Push Notification
  Future<void> scheduleDailyFinancialSummary() async {
    try {
      final summary = await calculateFinancialSummary();
      final title = '🌙 Daily Financial Summary (11:00 PM)';
      final body = '💸 Today Spent: ₹${summary.todaySpent.toStringAsFixed(2)}\n💰 Today Income: ₹${summary.todayIncome.toStringAsFixed(2)}\n💼 Overall Balance: ₹${summary.overallBalance.toStringAsFixed(2)}';

      await NotificationService.instance.scheduleDailyNotification(
        id: dailyFinanceSummaryNotifId,
        title: title,
        body: body,
        hour: 23, // 11:00 PM
        minute: 0,
        channelId: 'lifesync_finance_summary',
        channelName: 'Daily Financial Summary',
        channelDescription: 'Nightly 11:00 PM summary of spent, income, and balance',
        payload: 'financial_summary_11pm',
      );
      debugPrint('Daily 11:00 PM Financial Summary scheduled successfully.');
    } catch (e) {
      debugPrint('Error scheduling daily financial summary: $e');
    }
  }

  /// Trigger instant test push notification for 11:00 PM Financial Summary
  Future<void> sendInstantFinancialSummaryNotification() async {
    try {
      final summary = await calculateFinancialSummary();
      final title = '🌙 Daily Financial Summary (11:00 PM)';
      final body = '💸 Today Spent: ₹${summary.todaySpent.toStringAsFixed(2)}\n💰 Today Income: ₹${summary.todayIncome.toStringAsFixed(2)}\n💼 Overall Balance: ₹${summary.overallBalance.toStringAsFixed(2)}';

      await NotificationService.instance.showNotification(
        id: dailyFinanceSummaryNotifId,
        title: title,
        body: body,
        channelId: 'lifesync_finance_summary',
        channelName: 'Daily Financial Summary',
        channelDescription: 'Nightly 11:00 PM summary of spent, income, and balance',
        payload: 'financial_summary_test',
      );
    } catch (e) {
      debugPrint('Error sending instant financial summary notification: $e');
    }
  }

  /// Schedule recurring 6-hour interval pending task reminders (06:00, 12:00, 18:00, 00:00)
  Future<void> schedulePeriodicTaskReminders() async {
    try {
      final db = await AppDatabase.instance.database;
      final pendingTasks = await db.query(
        'todos',
        where: 'isCompleted = 0 AND isArchived = 0',
        orderBy: "CASE priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END, createdAt ASC",
      );

      final count = pendingTasks.length;
      if (count == 0) {
        // Cancel scheduled task reminders if no pending tasks exist
        for (final id in taskReminderNotifIds) {
          await NotificationService.instance.cancelNotification(id);
        }
        debugPrint('No pending tasks. Cancelled periodic task reminder schedules.');
        return;
      }

      final topTitlesList = pendingTasks.take(3).map((e) => '• ${e['title']}').join('\n');
      final moreText = count > 3 ? '\n...and ${count - 3} more task${count - 3 > 1 ? 's' : ''}' : '';

      final title = '📋 Pending Tasks Reminder ($count remaining)';
      final body = 'You have $count pending task${count > 1 ? 's' : ''} waiting:\n$topTitlesList$moreText\nTap to review and complete them!';

      // 4 checkpoints every 6 hours: 06:00, 12:00, 18:00, 00:00
      final checkpoints = [
        {'id': taskReminderNotifIds[0], 'hour': 6, 'min': 0},
        {'id': taskReminderNotifIds[1], 'hour': 12, 'min': 0},
        {'id': taskReminderNotifIds[2], 'hour': 18, 'min': 0},
        {'id': taskReminderNotifIds[3], 'hour': 0, 'min': 0},
      ];

      for (final cp in checkpoints) {
        await NotificationService.instance.scheduleDailyNotification(
          id: cp['id'] as int,
          title: title,
          body: body,
          hour: cp['hour'] as int,
          minute: cp['min'] as int,
          channelId: 'lifesync_task_reminders',
          channelName: 'Pending Task Reminders',
          channelDescription: 'Push reminders every 6 hours for incomplete tasks',
          payload: 'pending_tasks_reminder',
        );
      }

      debugPrint('Scheduled 6-hour pending task reminder checkpoints for $count tasks.');
    } catch (e) {
      debugPrint('Error scheduling periodic task reminders: $e');
    }
  }

  /// Trigger instant test push notification for 6-Hour Pending Task Reminder
  Future<void> sendInstantTaskReminderNotification() async {
    try {
      final db = await AppDatabase.instance.database;
      final pendingTasks = await db.query(
        'todos',
        where: 'isCompleted = 0 AND isArchived = 0',
        orderBy: "CASE priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END, createdAt ASC",
      );

      final count = pendingTasks.length;
      if (count == 0) {
        await NotificationService.instance.showNotification(
          id: 99999,
          title: '🎉 All Tasks Completed!',
          body: 'You have no pending tasks right now. Great job!',
          channelId: 'lifesync_task_reminders',
          channelName: 'Pending Task Reminders',
          payload: 'task_reminder_test',
        );
      } else {
        final topTitlesList = pendingTasks.take(3).map((e) => '• ${e['title']}').join('\n');
        final moreText = count > 3 ? '\n...and ${count - 3} more' : '';
        final title = '📋 Pending Tasks Reminder ($count remaining)';
        final body = 'You have $count pending task${count > 1 ? 's' : ''} waiting:\n$topTitlesList$moreText\nTap to review and complete them!';

        await NotificationService.instance.showNotification(
          id: 99999,
          title: title,
          body: body,
          channelId: 'lifesync_task_reminders',
          channelName: 'Pending Task Reminders',
          payload: 'task_reminder_test',
        );
      }
    } catch (e) {
      debugPrint('Error sending instant task reminder notification: $e');
    }
  }
}
