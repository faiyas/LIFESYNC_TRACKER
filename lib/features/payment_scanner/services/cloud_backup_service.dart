import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../database/app_database.dart';
import '../../ai_assistant/services/ai_backend_client.dart';
import '../models/detected_payment.dart';

class CloudBackupService {
  static const String _prefDeviceIdKey = 'lifesync_cloud_device_id';
  static final CloudBackupService instance = CloudBackupService._internal();

  String? _cachedDeviceId;

  CloudBackupService._internal();

  /// Gets or generates a permanent unique device ID for this phone
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefDeviceIdKey);
    if (id == null || id.isEmpty) {
      id = 'device_${const Uuid().v4().substring(0, 12)}';
      await prefs.setString(_prefDeviceIdKey, id);
    }
    _cachedDeviceId = id;
    return id;
  }

  /// Silently backs up a newly captured payment to Instabox Django backend
  Future<bool> backupSinglePayment(DetectedPayment payment) async {
    try {
      final deviceId = await getDeviceId();
      final backendUrl = AiBackendClient.instance.backendUrl;
      final uri = Uri.parse('$backendUrl/api/backup/push/');

      final date = payment.date ?? DateTime.now();
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

      final payload = {
        'device_id': deviceId,
        'device_name': Platform.isAndroid ? 'Android Phone' : 'iOS Device',
        'transactions': [
          {
            'id': payment.transactionId?.isNotEmpty == true ? payment.transactionId : const Uuid().v4(),
            'amount': payment.amount ?? 0.0,
            'is_income': payment.isIncome,
            'category': payment.isIncome ? payment.suggestedIncomeSource : payment.suggestedCategory,
            'merchant': payment.merchant ?? 'Payment',
            'source_type': payment.upiApp ?? 'notification',
            'transaction_id': payment.transactionId,
            'account_ending': payment.accountEnding,
            'date': dateStr,
            'time': timeStr,
            'notes': payment.rawText,
          }
        ]
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Cloud backup error: $e');
      return false;
    }
  }

  /// Bulk backs up all local SQLite expenses & income to Instabox
  Future<Map<String, dynamic>> backupAllLocalData() async {
    try {
      final deviceId = await getDeviceId();
      final backendUrl = AiBackendClient.instance.backendUrl;
      final uri = Uri.parse('$backendUrl/api/backup/push/');

      final db = await AppDatabase.instance.database;
      final expenses = await db.query('expenses');
      final incomes = await db.query('income');

      final List<Map<String, dynamic>> batch = [];

      for (final exp in expenses) {
        batch.add({
          'id': exp['id'],
          'amount': exp['amount'],
          'is_income': false,
          'category': exp['categoryId'] ?? 'General',
          'merchant': exp['location'] ?? 'Expense',
          'source_type': exp['paymentMethod'] ?? 'manual',
          'date': exp['date'],
          'time': exp['time'],
          'notes': exp['notes'],
        });
      }

      for (final inc in incomes) {
        batch.add({
          'id': inc['id'],
          'amount': inc['amount'],
          'is_income': true,
          'category': inc['categoryId'] ?? 'Income',
          'merchant': inc['source'] ?? 'Credit',
          'source_type': inc['paymentMethod'] ?? 'bank',
          'date': inc['date'],
          'notes': inc['notes'],
        });
      }

      if (batch.isEmpty) {
        return {'success': true, 'synced_count': 0, 'message': 'No local records to backup'};
      }

      final payload = {
        'device_id': deviceId,
        'device_name': Platform.isAndroid ? 'Android Phone' : 'iOS Device',
        'transactions': batch,
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'synced_count': batch.length,
          'data': jsonDecode(response.body),
        };
      }
      return {'success': false, 'error': 'Server HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Retrieves cloud stats (total backed up transactions and total sums)
  Future<Map<String, dynamic>?> getCloudStats() async {
    try {
      final deviceId = await getDeviceId();
      final backendUrl = AiBackendClient.instance.backendUrl;
      final uri = Uri.parse('$backendUrl/api/backup/stats/$deviceId/');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('Error getting cloud stats: $e');
    }
    return null;
  }
}
