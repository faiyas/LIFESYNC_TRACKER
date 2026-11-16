import 'package:flutter/foundation.dart';
import '../../../database/app_database.dart';
import '../../../models/models.dart';
import '../models/detected_payment.dart';
import 'payment_duplicate_service.dart';

class DeduplicationResult {
  final bool isDuplicate;
  final String? existingRecordId;
  final String reason;
  final bool canEnrich;

  const DeduplicationResult({
    required this.isDuplicate,
    this.existingRecordId,
    required this.reason,
    this.canEnrich = false,
  });
}

class PaymentDeduplicationEngine {
  static final PaymentDeduplicationEngine instance = PaymentDeduplicationEngine._internal();
  PaymentDeduplicationEngine._internal();

  // In-memory sliding window cache of recent transaction fingerprints:
  // Key: fingerprint hash, Value: timestamp ms
  final Map<String, int> _recentFingerprintCache = {};
  static const int _cacheExpiryMs = 24 * 60 * 60 * 1000; // 24 hours

  int _duplicatesPreventedCount = 0;
  int get duplicatesPreventedCount => _duplicatesPreventedCount;

  void resetDuplicateStats() {
    _duplicatesPreventedCount = 0;
  }

  /// Normalize merchant / sender / receiver name for robust cross-channel comparison
  /// E.g., "SWIGGY UPI", "Swiggy Bundl Tech", "Paid to Swiggy" -> "swiggy"
  static String normalizeMerchant(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    String clean = raw.toLowerCase().trim();

    clean = clean
        .replaceAll(RegExp(r'\b(?:pvt|ltd|limited|private|llp|inc|co|corp)\b'), '')
        .replaceAll(RegExp(r'\b(?:upi|vpa|pay|wallet|gpay|phonepe|paytm)\b'), '')
        .replaceAll(RegExp(r'\b(?:paid to|transferred to|sent to|received from|received in)\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return clean;
  }

  /// Generate fingerprint hash for memory cache incorporating amount, date, sender/receiver, account, and txnId
  static String generateFingerprint({
    required double amount,
    required String dateStr,
    String? merchant,
    String? accountEnding,
    String? transactionId,
    bool isIncome = false,
  }) {
    if (transactionId != null && transactionId.trim().isNotEmpty) {
      return 'txn_${transactionId.trim().toUpperCase()}';
    }
    final normalized = normalizeMerchant(merchant);
    final acct = accountEnding ?? '';
    return '${isIncome ? "inc" : "exp"}_${amount.toStringAsFixed(2)}_${dateStr}_${normalized}_$acct';
  }

  /// Clean old entries from in-memory cache
  void _evictExpiredCache() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentFingerprintCache.removeWhere((_, time) => (now - time) > _cacheExpiryMs);
  }

  /// Primary multi-channel deduplication check comparing:
  /// 1. Transaction ID
  /// 2. Bank Account Ending
  /// 3. Sender / Receiver Name
  /// 4. Time Proximity & Date
  /// 5. Amount & Debit vs Credit separation
  Future<DeduplicationResult> checkDuplicate(DetectedPayment payment) async {
    _evictExpiredCache();

    final amount = payment.amount;
    if (amount == null || amount <= 0) {
      return const DeduplicationResult(isDuplicate: true, reason: 'Invalid or zero amount');
    }

    final date = payment.date ?? DateTime.now();
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final txnId = payment.transactionId?.trim();
    final merchantNorm = normalizeMerchant(payment.merchant);
    final accountEnding = payment.accountEnding?.trim();

    // 1. Transaction ID match (Highest precision across both memory and database)
    if (txnId != null && txnId.isNotEmpty) {
      final txnFingerprint = 'txn_${txnId.toUpperCase()}';
      if (_recentFingerprintCache.containsKey(txnFingerprint)) {
        _duplicatesPreventedCount++;
        return DeduplicationResult(
          isDuplicate: true,
          reason: 'Duplicate blocked: Transaction ID #$txnId already recorded in memory cache.',
        );
      }

      final hasInDb = await PaymentDuplicateService.hasTransactionId(txnId);
      if (hasInDb) {
        _duplicatesPreventedCount++;
        final existing = await PaymentDuplicateService.findByTransactionId(txnId);
        return DeduplicationResult(
          isDuplicate: true,
          existingRecordId: existing?.id,
          reason: 'Duplicate blocked: Transaction ID #$txnId already saved in database.',
          canEnrich: true,
        );
      }
    }

    // 2. In-memory fingerprint match (Instant race-condition guard for simultaneous notifications/SMS)
    final memoryFp = generateFingerprint(
      amount: amount,
      dateStr: dateStr,
      merchant: merchantNorm,
      accountEnding: accountEnding,
      transactionId: txnId,
      isIncome: payment.isIncome,
    );

    if (_recentFingerprintCache.containsKey(memoryFp)) {
      _duplicatesPreventedCount++;
      return DeduplicationResult(
        isDuplicate: true,
        reason: 'Duplicate blocked: ${payment.isIncome ? "Credit" : "Debit"} of ₹${amount.toStringAsFixed(2)} to "$merchantNorm" was just logged moments ago.',
      );
    }

    // 3. Database match: STRICT separation (debited checks expenses, credited checks income)
    final db = await AppDatabase.instance.database;
    final tableName = payment.isIncome ? 'income' : 'expenses';

    final rows = await db.query(
      tableName,
      where: 'amount = ? AND date = ?',
      whereArgs: [amount, dateStr],
    );

    if (rows.isNotEmpty) {
      for (final row in rows) {
        final existingMerchant = payment.isIncome ? (row['source'] as String? ?? '') : (row['location'] as String? ?? '');
        final existingNotes = row['notes'] as String? ?? '';
        final existingNorm = normalizeMerchant(existingMerchant.isNotEmpty ? existingMerchant : existingNotes);

        // A. Account ending match check (e.g. ••4582 or XX1234)
        bool accountMatches = true;
        if (accountEnding != null && accountEnding.isNotEmpty) {
          if (existingNotes.contains(accountEnding)) {
            accountMatches = true;
          }
        }

        // B. Sender / Receiver match check
        bool merchantMatches = false;
        if (merchantNorm.isEmpty || existingNorm.isEmpty) {
          merchantMatches = true;
        } else if (merchantNorm == existingNorm ||
            merchantNorm.contains(existingNorm) ||
            existingNorm.contains(merchantNorm)) {
          merchantMatches = true;
        }

        // C. Time proximity check (if time string is present in existing record)
        bool timeProximityMatches = true;
        final existingTimeStr = row['time'] as String?;
        if (existingTimeStr != null && existingTimeStr.isNotEmpty) {
          try {
            final nowTime = DateTime.now();
            final parts = existingTimeStr.split(':');
            if (parts.length >= 2) {
              final existingHour = int.parse(parts[0]);
              final existingMinute = int.parse(parts[1]);
              final diffMinutes = (nowTime.hour * 60 + nowTime.minute) - (existingHour * 60 + existingMinute);
              // If difference is within 90 minutes, consider same transaction window
              if (diffMinutes.abs() > 90) {
                timeProximityMatches = false;
              }
            }
          } catch (_) {}
        }

        if (merchantMatches && accountMatches && timeProximityMatches) {
          _duplicatesPreventedCount++;
          return DeduplicationResult(
            isDuplicate: true,
            existingRecordId: row['id'] as String?,
            reason: 'Duplicate blocked: Matching $tableName record for ₹${amount.toStringAsFixed(2)} already exists for today.',
            canEnrich: true,
          );
        }
      }
    }

    return const DeduplicationResult(isDuplicate: false, reason: 'Unique transaction');
  }

  /// Register a successfully saved payment into the deduplication cache
  void registerProcessedPayment(DetectedPayment payment) {
    final amount = payment.amount ?? 0;
    final date = payment.date ?? DateTime.now();
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final now = DateTime.now().millisecondsSinceEpoch;

    if (payment.transactionId != null && payment.transactionId!.trim().isNotEmpty) {
      _recentFingerprintCache['txn_${payment.transactionId!.trim().toUpperCase()}'] = now;
    }

    final fp = generateFingerprint(
      amount: amount,
      dateStr: dateStr,
      merchant: payment.merchant,
      accountEnding: payment.accountEnding,
      transactionId: payment.transactionId,
      isIncome: payment.isIncome,
    );
    _recentFingerprintCache[fp] = now;
  }

  /// Enrich an existing record with additional SMS or screenshot details (e.g. Bank Ref, A/C number)
  Future<void> enrichExistingRecord({
    required String recordId,
    required DetectedPayment newPayment,
    required String source,
  }) async {
    try {
      final db = await AppDatabase.instance.database;
      final tableName = newPayment.isIncome ? 'income' : 'expenses';
      final existingRows = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [recordId],
        limit: 1,
      );

      if (existingRows.isEmpty) return;
      final existing = existingRows.first;
      final currentNotes = existing['notes'] as String? ?? '';

      final additions = <String>[];
      if (newPayment.transactionId != null &&
          newPayment.transactionId!.isNotEmpty &&
          !currentNotes.contains(newPayment.transactionId!)) {
        additions.add('Txn Ref: ${newPayment.transactionId}');
      }
      if (newPayment.accountEnding != null &&
          newPayment.accountEnding!.isNotEmpty &&
          !currentNotes.contains(newPayment.accountEnding!)) {
        additions.add('A/C: ••${newPayment.accountEnding}');
      }
      if (newPayment.upiId != null &&
          newPayment.upiId!.isNotEmpty &&
          !currentNotes.contains(newPayment.upiId!)) {
        additions.add('UPI: ${newPayment.upiId}');
      }
      if (source == 'sms' && !currentNotes.contains('[Bank SMS Verified]')) {
        additions.add('[Bank SMS Verified]');
      }

      if (additions.isNotEmpty) {
        final updatedNotes = currentNotes.isEmpty
            ? additions.join(' | ')
            : '$currentNotes | ${additions.join(' | ')}';

        await db.update(
          tableName,
          {'notes': updatedNotes},
          where: 'id = ?',
          whereArgs: [recordId],
        );
        debugPrint('Enriched $tableName record $recordId with additional metadata from $source');
      }
    } catch (e) {
      debugPrint('Error enriching record: $e');
    }
  }
}
