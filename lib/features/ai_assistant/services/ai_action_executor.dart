import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../database/app_database.dart';
import '../../../models/models.dart';
import '../../../services/notification_service.dart';

class ActionExecutionResult {
  final bool success;
  final String message;
  final String? recordId;

  ActionExecutionResult({
    required this.success,
    required this.message,
    this.recordId,
  });
}

class AiActionExecutor {
  static final AiActionExecutor instance = AiActionExecutor._internal();
  AiActionExecutor._internal();

  Future<ActionExecutionResult> executeAction({
    required String actionType,
    required Map<String, dynamic> payload,
  }) async {
    try {
      switch (actionType.toLowerCase()) {
        case 'reminder':
          return await _executeReminder(payload);
        case 'expense':
          return await _executeExpense(payload);
        case 'income':
          return await _executeIncome(payload);
        case 'image':
          return ActionExecutionResult(
            success: true,
            message: 'Image generated successfully',
          );
        default:
          return ActionExecutionResult(
            success: false,
            message: 'Unknown action type: $actionType',
          );
      }
    } catch (e) {
      debugPrint('Error executing AI action ($actionType): $e');
      return ActionExecutionResult(
        success: false,
        message: 'Failed to execute: $e',
      );
    }
  }

  /// Schedules a system push reminder
  Future<ActionExecutionResult> _executeReminder(Map<String, dynamic> payload) async {
    final title = payload['title'] as String? ?? 'Reminder';
    final timeRaw = payload['time'] as String?;

    DateTime scheduledTime = DateTime.now().add(const Duration(hours: 1));
    if (timeRaw != null) {
      try {
        scheduledTime = DateTime.parse(timeRaw);
      } catch (_) {
        try {
          scheduledTime = DateFormat('yyyy-MM-dd HH:mm').parse(timeRaw);
        } catch (_) {}
      }
    }

    if (scheduledTime.isBefore(DateTime.now())) {
      scheduledTime = DateTime.now().add(const Duration(minutes: 5));
    }

    final notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final formattedTime = DateFormat('MMM d, hh:mm a').format(scheduledTime);

    await NotificationService.instance.scheduleNotification(
      id: notifId,
      title: '⏰ $title',
      body: 'LifeSync Assistant reminder: $title',
      scheduledDateTime: scheduledTime,
      channelId: 'lifesync_reminders',
      channelName: 'LifeSync Reminders & Alerts',
    );

    return ActionExecutionResult(
      success: true,
      message: 'Reminder scheduled for $formattedTime',
      recordId: notifId.toString(),
    );
  }

  /// Inserts an expense into Drift/Sqflite AppDatabase
  Future<ActionExecutionResult> _executeExpense(Map<String, dynamic> payload) async {
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount <= 0) {
      return ActionExecutionResult(success: false, message: 'Invalid expense amount');
    }

    final category = payload['category'] as String? ?? 'General';
    final merchant = payload['merchant'] as String? ?? 'Expense';
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm').format(now);

    final expense = Expense(
      profileId: 'default_profile',
      amount: amount,
      categoryId: category,
      paymentMethod: 'Cash/Digital',
      date: dateStr,
      time: timeStr,
      notes: '[Logged via AI Assistant] $merchant',
      location: merchant,
    );

    final db = await AppDatabase.instance.database;
    await db.insert('expenses', expense.toMap());

    // Show a quick notification confirming the logging
    await NotificationService.instance.showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: '⚡ Expense Logged: ₹${amount.toStringAsFixed(0)}',
      body: '$merchant categorized under $category',
    );

    return ActionExecutionResult(
      success: true,
      message: 'Logged ₹${amount.toStringAsFixed(2)} to $category',
      recordId: expense.id,
    );
  }

  /// Inserts income into Drift/Sqflite AppDatabase
  Future<ActionExecutionResult> _executeIncome(Map<String, dynamic> payload) async {
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount <= 0) {
      return ActionExecutionResult(success: false, message: 'Invalid income amount');
    }

    final source = payload['source'] as String? ?? 'Income';
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);

    final income = Income(
      profileId: 'default_profile',
      amount: amount,
      categoryId: 'Salary/Credit',
      source: source,
      paymentMethod: 'Bank Transfer',
      date: dateStr,
      notes: '[Logged via AI Assistant] Received from $source',
      isTaxRelevant: false,
    );

    final db = await AppDatabase.instance.database;
    await db.insert('income', income.toMap());

    // Show confirmation notification
    await NotificationService.instance.showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: '💰 Income Recorded: ₹${amount.toStringAsFixed(0)}',
      body: 'Credited from $source',
    );

    return ActionExecutionResult(
      success: true,
      message: 'Recorded ₹${amount.toStringAsFixed(2)} from $source',
      recordId: income.id,
    );
  }
}
