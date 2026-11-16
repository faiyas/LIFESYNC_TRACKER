import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../database/app_database.dart';
import '../../../models/models.dart';
import '../../../services/app_notification_scheduler.dart';
import '../../../services/notification_service.dart';
import '../models/detected_payment.dart';
import 'auto_payment_channel.dart';
import 'payment_deduplication_engine.dart';
import 'payment_ocr_service.dart';
import 'payment_parser_service.dart';

class AutoCapturedEvent {
  final String id;
  final String? createdRecordId;
  final bool isIncome;
  final DetectedPayment payment;
  final String source; // 'sms', 'notification', 'screenshot'
  final DateTime timestamp;
  final bool wasSaved;
  final bool wasDuplicate;
  final String statusMessage;

  AutoCapturedEvent({
    required this.id,
    this.createdRecordId,
    this.isIncome = false,
    required this.payment,
    required this.source,
    required this.timestamp,
    required this.wasSaved,
    required this.wasDuplicate,
    required this.statusMessage,
  });
}

class AutoPaymentManager with ChangeNotifier {
  static final AutoPaymentManager instance = AutoPaymentManager._internal();
  AutoPaymentManager._internal();

  final _channel = AutoPaymentChannel.instance;
  final _parser = PaymentParserService();
  final _ocrService = PaymentOcrService();
  final _dedup = PaymentDeduplicationEngine.instance;

  Timer? _periodicSyncTimer;
  bool _isSyncing = false;
  bool _initialized = false;

  // Configuration Preferences
  bool _isAutoTrackingEnabled = true;
  bool _isSmsEnabled = true;
  bool _isNotificationEnabled = true;
  bool _isScreenshotWatcherEnabled = true;
  bool _isAutoSaveDirectly = true; // Auto-save vs Review Queue

  int _lastSmsCheckTimestamp = 0;
  int _lastScreenshotCheckTimestamp = 0;

  // History & Pending Queues
  final List<AutoCapturedEvent> _recentActivity = [];
  final List<DetectedPayment> _pendingReviewQueue = [];

  // Getters
  bool get isAutoTrackingEnabled => _isAutoTrackingEnabled;
  bool get isSmsEnabled => _isSmsEnabled;
  bool get isNotificationEnabled => _isNotificationEnabled;
  bool get isScreenshotWatcherEnabled => _isScreenshotWatcherEnabled;
  bool get isAutoSaveDirectly => _isAutoSaveDirectly;
  bool get isSyncing => _isSyncing;
  List<AutoCapturedEvent> get recentActivity => List.unmodifiable(_recentActivity);
  List<DetectedPayment> get pendingReviewQueue => List.unmodifiable(_pendingReviewQueue);
  int get duplicatesPrevented => _dedup.duplicatesPreventedCount;

  static const _prefAutoTracking = 'auto_pay_tracking_enabled';
  static const _prefSmsEnabled = 'auto_pay_sms_enabled';
  static const _prefNotifEnabled = 'auto_pay_notif_enabled';
  static const _prefScreenshotEnabled = 'auto_pay_screenshot_enabled';
  static const _prefAutoSaveDirectly = 'auto_pay_save_directly';
  static const _prefLastSmsCheck = 'auto_pay_last_sms_check';
  static const _prefLastScreenshotCheck = 'auto_pay_last_screenshot_check';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Load preferences
    final prefs = await SharedPreferences.getInstance();
    _isAutoTrackingEnabled = prefs.getBool(_prefAutoTracking) ?? true;
    _isSmsEnabled = prefs.getBool(_prefSmsEnabled) ?? true;
    _isNotificationEnabled = prefs.getBool(_prefNotifEnabled) ?? true;
    _isScreenshotWatcherEnabled = prefs.getBool(_prefScreenshotEnabled) ?? true;
    _isAutoSaveDirectly = prefs.getBool(_prefAutoSaveDirectly) ?? true;
    _lastSmsCheckTimestamp = prefs.getInt(_prefLastSmsCheck) ?? (DateTime.now().millisecondsSinceEpoch - (24 * 60 * 60 * 1000));
    _lastScreenshotCheckTimestamp = prefs.getInt(_prefLastScreenshotCheck) ?? (DateTime.now().millisecondsSinceEpoch - (24 * 60 * 60 * 1000));

    // Initialize native channel callbacks
    _channel.initialize();
    _channel.onNotificationReceived = _handleLiveNotification;
    _channel.onSmsReceived = _handleLiveSms;

    // Start periodic background check timer (every 30 seconds when app is active)
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isAutoTrackingEnabled) {
        syncAllChannelsNow();
      }
    });

    // Run initial sync after short delay
    Future.delayed(const Duration(seconds: 3), () {
      if (_isAutoTrackingEnabled) {
        syncAllChannelsNow();
      }
    });
  }

  // Setters with persistent storage
  Future<void> setAutoTrackingEnabled(bool val) async {
    _isAutoTrackingEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoTracking, val);
    notifyListeners();
  }

  Future<void> setSmsEnabled(bool val) async {
    _isSmsEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSmsEnabled, val);
    notifyListeners();
  }

  Future<void> setNotificationEnabled(bool val) async {
    _isNotificationEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefNotifEnabled, val);
    notifyListeners();
  }

  Future<void> setScreenshotWatcherEnabled(bool val) async {
    _isScreenshotWatcherEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefScreenshotEnabled, val);
    notifyListeners();
  }

  Future<void> setAutoSaveDirectly(bool val) async {
    _isAutoSaveDirectly = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoSaveDirectly, val);
    notifyListeners();
  }

  /// Request SMS permission from Android system
  Future<bool> requestSmsPermission() async {
    final granted = await _channel.requestSmsPermission();
    notifyListeners();
    return granted;
  }

  /// Check SMS permission status
  Future<bool> checkSmsPermission() async {
    return await _channel.checkSmsPermission();
  }

  /// Check notification listener permission status
  Future<bool> isNotificationListenerEnabled() async {
    return await _channel.isNotificationListenerEnabled();
  }

  /// Open Android Notification Access Settings
  Future<void> openNotificationListenerSettings() async {
    await _channel.openNotificationListenerSettings();
  }

  /// Comprehensive multi-channel sync (SMS + Notifications + Screenshots)
  Future<int> syncAllChannelsNow() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    notifyListeners();

    int totalProcessed = 0;
    try {
      // 1. Process Channel: Notifications buffer
      if (_isNotificationEnabled) {
        final notifications = await _channel.getPendingNotifications();
        for (final notif in notifications) {
          final processed = await _processRawNotification(notif);
          if (processed) totalProcessed++;
        }
      }

      // 2. Process Channel: SMS buffer & Inbox query
      if (_isSmsEnabled) {
        final pendingSms = await _channel.getPendingSms();
        for (final sms in pendingSms) {
          final processed = await _processRawSms(sms);
          if (processed) totalProcessed++;
        }

        final hasSmsPerm = await _channel.checkSmsPermission();
        if (hasSmsPerm) {
          final inboxSms = await _channel.readRecentSms(
            sinceTimestamp: _lastSmsCheckTimestamp,
            limit: 25,
          );
          for (final sms in inboxSms) {
            final processed = await _processRawSms(sms);
            if (processed) totalProcessed++;
          }
          _lastSmsCheckTimestamp = DateTime.now().millisecondsSinceEpoch;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_prefLastSmsCheck, _lastSmsCheckTimestamp);
        }
      }

      // 3. Process Channel: Screenshot folder watcher
      if (_isScreenshotWatcherEnabled) {
        final screenshots = await _channel.getRecentScreenshots(
          sinceTimestamp: _lastScreenshotCheckTimestamp,
          limit: 15,
        );
        for (final shot in screenshots) {
          final path = shot['path'] as String? ?? '';
          if (path.isNotEmpty && File(path).existsSync()) {
            final processed = await _processScreenshotFile(path);
            if (processed) totalProcessed++;
          }
        }
        _lastScreenshotCheckTimestamp = DateTime.now().millisecondsSinceEpoch;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefLastScreenshotCheck, _lastScreenshotCheckTimestamp);
      }
    } catch (e) {
      debugPrint('Error syncing automated payments: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }

    return totalProcessed;
  }

  // Live event handlers
  Future<void> _handleLiveNotification(Map<String, dynamic> notif) async {
    if (!_isAutoTrackingEnabled || !_isNotificationEnabled) return;
    await _processRawNotification(notif);
    notifyListeners();
  }

  Future<void> _handleLiveSms(Map<String, dynamic> sms) async {
    if (!_isAutoTrackingEnabled || !_isSmsEnabled) return;
    await _processRawSms(sms);
    notifyListeners();
  }

  /// Simulate an incoming UPI notification for testing & verification
  Future<bool> simulateNotification({required String title, required String body}) async {
    final res = await _processRawNotification({
      'title': title,
      'body': body,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    notifyListeners();
    return res;
  }

  /// Simulate an incoming Bank SMS for testing & verification
  Future<bool> simulateSms({required String sender, required String body}) async {
    final res = await _processRawSms({
      'sender': sender,
      'body': body,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    notifyListeners();
    return res;
  }

  // Processing pipeline
  Future<bool> _processRawNotification(Map<String, dynamic> notif) async {
    final title = notif['title'] as String? ?? '';
    final body = notif['body'] as String? ?? '';
    final pkg = notif['packageName'] as String? ?? '';

    // 1. NEVER listen to our own notifications!
    if (pkg.contains('lifesync') || title.contains('LifeSync') || body.contains('Auto-Logged')) {
      return false;
    }

    final fullText = '$title\n$body';
    final lower = fullText.toLowerCase();

    // 2. STRICT: Must explicitly contain a real debited/credited/paid/received action
    final hasStrictAction = lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('paid to') ||
        lower.contains('paid successfully') ||
        lower.contains('payment successful') ||
        lower.contains('payment of') ||
        lower.contains('you paid') ||
        lower.contains('received from') ||
        lower.contains('money received') ||
        lower.contains('payment received') ||
        lower.contains('transferred to') ||
        lower.contains('transferred from') ||
        lower.contains('transfer successful') ||
        lower.contains('upi ref') ||
        lower.contains('txn id') ||
        lower.contains('utr');

    if (!hasStrictAction) {
      return false;
    }

    if (!_parser.isPaymentScreenshot(fullText)) return false;

    final detected = _parser.parse(fullText);
    if (!detected.isValidPayment || (detected.amount == null || detected.amount! <= 0)) {
      return false;
    }

    return await _handleDetectedPayment(detected, source: 'notification');
  }

  Future<bool> _processRawSms(Map<String, dynamic> sms) async {
    final body = sms['body'] as String? ?? '';
    final sender = sms['sender'] as String? ?? '';
    final fullText = 'Sender: $sender\n$body';
    final lower = fullText.toLowerCase();

    // STRICT: Must explicitly contain debited, credited, or transaction ref
    final hasStrictAction = lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('spent') ||
        lower.contains('paid') ||
        lower.contains('withdrawn') ||
        lower.contains('upi ref') ||
        lower.contains('txn id') ||
        lower.contains('utr');

    if (!hasStrictAction) {
      return false;
    }

    if (!_parser.isPaymentScreenshot(fullText)) return false;

    final detected = _parser.parse(fullText);
    if (!detected.isValidPayment || (detected.amount == null || detected.amount! <= 0)) {
      return false;
    }

    return await _handleDetectedPayment(detected, source: 'sms');
  }

  Future<bool> _processScreenshotFile(String path) async {
    try {
      final ocrText = await _ocrService.extractText(path);
      if (ocrText.isEmpty || !_parser.isPaymentScreenshot(ocrText)) return false;

      final detected = _parser.parse(ocrText, imagePath: path);
      if (!detected.isValidPayment || (detected.amount == null || detected.amount! <= 0)) {
        return false;
      }

      return await _handleDetectedPayment(detected, source: 'screenshot');
    } catch (e) {
      debugPrint('Error processing screenshot file $path: $e');
      return false;
    }
  }

  /// Core logic: Deduplication check, Enrichment, and Auto-Saving
  Future<bool> _handleDetectedPayment(DetectedPayment payment, {required String source}) async {
    // Check against Deduplication Engine (Time, Account, Sender, Receiver, Txn ID, Amount)
    final dedupResult = await _dedup.checkDuplicate(payment);

    if (dedupResult.isDuplicate) {
      if (dedupResult.canEnrich && dedupResult.existingRecordId != null) {
        await _dedup.enrichExistingRecord(
          recordId: dedupResult.existingRecordId!,
          newPayment: payment,
          source: source,
        );
      }

      _recordActivity(
        payment: payment,
        source: source,
        wasSaved: false,
        wasDuplicate: true,
        message: 'Duplicate prevented: ${dedupResult.reason}',
      );
      return false;
    }

    _dedup.registerProcessedPayment(payment);

    if (_isAutoSaveDirectly) {
      // Save directly to AppDatabase (Credit -> Income, Debit -> Expenses)
      final recordId = await _savePaymentToDatabase(payment, source);
      _recordActivity(
        payment: payment,
        source: source,
        createdRecordId: recordId,
        isIncome: payment.isIncome,
        wasSaved: true,
        wasDuplicate: false,
        message: 'Auto-saved to ${payment.isIncome ? "Income" : "Expenses"} via $source',
      );

      _showAutoCaptureNotification(payment, source);
      return true;
    } else {
      _pendingReviewQueue.insert(0, payment);
      _recordActivity(
        payment: payment,
        source: source,
        isIncome: payment.isIncome,
        wasSaved: false,
        wasDuplicate: false,
        message: 'Queued for review from $source',
      );
      _showReviewQueueNotification(payment, source);
      return true;
    }
  }

  /// Inserts transaction into SQLite AppDatabase:
  /// - Credited -> income table
  /// - Debited -> expenses table
  /// Returns the inserted record ID
  Future<String?> _savePaymentToDatabase(DetectedPayment payment, String source) async {
    try {
      final db = await AppDatabase.instance.database;
      final date = payment.date ?? DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final timeStr = DateFormat('HH:mm').format(date);
      const activeProfile = 'default_profile';

      final amount = payment.amount ?? 0.0;
      final merchant = payment.merchant ?? 'Payment';
      final method = payment.paymentMethod ?? (payment.upiApp ?? 'UPI');

      final notesBuilder = StringBuffer();
      notesBuilder.write('[Auto-Logged from $source]');
      if (payment.transactionId != null && payment.transactionId!.isNotEmpty) {
        notesBuilder.write(' Txn Ref: ${payment.transactionId}');
      }
      if (payment.accountEnding != null && payment.accountEnding!.isNotEmpty) {
        notesBuilder.write(' A/C: ••${payment.accountEnding}');
      }
      if (payment.upiId != null && payment.upiId!.isNotEmpty) {
        notesBuilder.write(' UPI: ${payment.upiId}');
      }
      if (payment.itemSummary != null && payment.itemSummary!.isNotEmpty) {
        notesBuilder.write(' Items: ${payment.itemSummary}');
      }

      if (payment.isIncome) {
        final income = Income(
          profileId: activeProfile,
          amount: amount,
          categoryId: payment.suggestedIncomeSource,
          source: merchant,
          paymentMethod: method,
          date: dateStr,
          notes: notesBuilder.toString(),
          isTaxRelevant: false,
        );
        await db.insert('income', income.toMap());
        AppNotificationScheduler.instance.scheduleDailyFinancialSummary();
        return income.id;
      } else {
        final expense = Expense(
          profileId: activeProfile,
          amount: amount,
          categoryId: payment.suggestedCategory,
          paymentMethod: method,
          date: dateStr,
          time: timeStr,
          notes: notesBuilder.toString(),
          location: merchant,
          receiptUri: payment.imagePath,
          currency: 'INR',
        );
        await db.insert('expenses', expense.toMap());
        AppNotificationScheduler.instance.scheduleDailyFinancialSummary();
        return expense.id;
      }
    } catch (e) {
      debugPrint('Error saving auto payment to database: $e');
      return null;
    }
  }

  void _showAutoCaptureNotification(DetectedPayment payment, String source) {
    try {
      final amountStr = '₹${(payment.amount ?? 0).toStringAsFixed(2)}';
      final payee = payment.merchant ?? 'Merchant';
      final type = payment.isIncome ? 'income from $payee' : 'spent at $payee';

      NotificationService.instance.showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: '⚡ Auto-Logged: $amountStr',
        body: 'Automatically recorded $type via ${source.toUpperCase()}. Tap to view in Finance.',
        payload: 'auto_payment_${payment.isIncome ? "income" : "expense"}',
      );
    } catch (_) {}
  }

  void _showReviewQueueNotification(DetectedPayment payment, String source) {
    try {
      final amountStr = '₹${(payment.amount ?? 0).toStringAsFixed(2)}';
      NotificationService.instance.showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: '🧾 Payment Detected: $amountStr',
        body: 'Captured from ${source.toUpperCase()}. Tap to review and confirm.',
        payload: 'review_pending_payments',
      );
    } catch (_) {}
  }

  void _recordActivity({
    required DetectedPayment payment,
    required String source,
    String? createdRecordId,
    bool isIncome = false,
    required bool wasSaved,
    required bool wasDuplicate,
    required String message,
  }) {
    final event = AutoCapturedEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdRecordId: createdRecordId,
      isIncome: isIncome,
      payment: payment,
      source: source,
      timestamp: DateTime.now(),
      wasSaved: wasSaved,
      wasDuplicate: wasDuplicate,
      statusMessage: message,
    );
    _recentActivity.insert(0, event);
    if (_recentActivity.length > 100) {
      _recentActivity.removeLast();
    }
  }

  /// Delete an event from activity history AND permanently delete the created record from SQLite database
  Future<void> deleteCapturedEvent(AutoCapturedEvent event) async {
    try {
      if (event.createdRecordId != null && event.createdRecordId!.isNotEmpty) {
        final db = await AppDatabase.instance.database;
        final table = event.isIncome ? 'income' : 'expenses';
        await db.delete(table, where: 'id = ?', whereArgs: [event.createdRecordId]);
      }
      _recentActivity.remove(event);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting captured event: $e');
    }
  }

  /// Manually confirm and save an item from the review queue
  Future<void> confirmReviewPayment(DetectedPayment payment, {String? category, String? method}) async {
    final updatedPayment = payment.copyWith(
      suggestedCategory: category,
      paymentMethod: method,
    );
    final recordId = await _savePaymentToDatabase(updatedPayment, 'manual_review');
    _pendingReviewQueue.remove(payment);
    _recordActivity(
      payment: updatedPayment,
      source: 'review_queue',
      createdRecordId: recordId,
      isIncome: updatedPayment.isIncome,
      wasSaved: true,
      wasDuplicate: false,
      message: 'Approved and saved to database',
    );
    notifyListeners();
  }

  /// Discard an item from the review queue
  void discardReviewPayment(DetectedPayment payment) {
    _pendingReviewQueue.remove(payment);
    notifyListeners();
  }

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    super.dispose();
  }
}
