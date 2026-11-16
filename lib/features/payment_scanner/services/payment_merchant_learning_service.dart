import '../../../database/app_database.dart';
import '../models/detected_payment.dart';

class MerchantHistoricalMatch {
  final String? categoryId;
  final String? incomeSource;
  final String? paymentMethod;
  final int frequency;
  final String matchedMerchant;

  const MerchantHistoricalMatch({
    this.categoryId,
    this.incomeSource,
    this.paymentMethod,
    this.frequency = 1,
    required this.matchedMerchant,
  });
}

class MerchantSpendingGroup {
  final String merchantName;
  final double totalAmount;
  final int count;
  final double averageAmount;
  final List<DetectedPayment> payments;
  final bool isIncome;

  const MerchantSpendingGroup({
    required this.merchantName,
    required this.totalAmount,
    required this.count,
    required this.averageAmount,
    required this.payments,
    this.isIncome = false,
  });
}

class PaymentMerchantLearningService {
  static final PaymentMerchantLearningService instance = PaymentMerchantLearningService._();
  PaymentMerchantLearningService._();

  /// Clean and normalize merchant names from OCR text
  String normalizeMerchantName(String raw) {
    var cleaned = raw.trim();

    // Strip leading avatar / bullet chars
    cleaned = cleaned.replaceAll(RegExp(r'^[A-Za-z0-9]\s+(?=[A-Za-z])'), '');

    // Strip common UPI prefixes & noise
    cleaned = cleaned.replaceAll(RegExp(r'^(?:UPI[\/\-:]?|Paid to\s*|Paying to\s*|Sent to\s*|Transfer to\s*|To:\s*|From:\s*)', caseSensitive: false), '').trim();

    // Strip trailing reference IDs or VPA handles if appended
    cleaned = cleaned.replaceAll(RegExp(r'\s+[a-zA-Z0-9.\-_]+@[a-zA-Z0-9]+.*$'), '').trim();

    // Strip trailing invoice or phone numbers
    cleaned = cleaned.replaceAll(RegExp(r'\s+(?:Ph|Mob|Tel|Bill|Inv|Tax)[\s:\-]*\d+.*$', caseSensitive: false), '').trim();

    // Specific well-known brand normalizations
    final lower = cleaned.toLowerCase();
    if (lower.contains('swiggy')) return 'Swiggy';
    if (lower.contains('zomato')) return 'Zomato';
    if (lower.contains('blinkit')) return 'Blinkit';
    if (lower.contains('zepto')) return 'Zepto';
    if (lower.contains('instamart')) return 'Swiggy Instamart';
    if (lower.contains('bigbasket') || lower.contains('bb daily')) return 'BigBasket';
    if (lower.contains('dmart') || lower.contains('d-mart') || lower.contains('avenue supermarts')) return 'DMart';
    if (lower.contains('reliance fresh') || lower.contains('reliance smart')) return 'Reliance Smart';
    if (lower.contains('amazon')) return 'Amazon';
    if (lower.contains('flipkart')) return 'Flipkart';
    if (lower.contains('myntra')) return 'Myntra';
    if (lower.contains('uber')) return 'Uber';
    if (lower.contains('ola')) return 'Ola';
    if (lower.contains('rapido')) return 'Rapido';
    if (lower.contains('apollo')) return 'Apollo Pharmacy';
    if (lower.contains('medplus')) return 'MedPlus';
    if (lower.contains('starbucks')) return 'Starbucks';
    if (lower.contains('mcdonald')) return "McDonald's";
    if (lower.contains('kfc')) return 'KFC';
    if (lower.contains('domino')) return "Domino's Pizza";
    if (lower.contains('pizza hut')) return 'Pizza Hut';
    if (lower.contains('indian oil') || lower.contains('iocl')) return 'Indian Oil';
    if (lower.contains('bharat petroleum') || lower.contains('bpcl')) return 'Bharat Petroleum';
    if (lower.contains('hindustan petroleum') || lower.contains('hpcl')) return 'HPCL Petrol';
    if (lower.contains('shell petrol') || lower.contains('shell')) return 'Shell';
    if (lower.contains('ksrtc')) return 'KSRTC';
    if (lower.contains('tnstc')) return 'TNSTC';
    if (lower.contains('bmtc')) return 'BMTC';
    if (lower.contains('irctc')) return 'IRCTC';
    if (lower.contains('indian railways')) return 'Indian Railways';
    if (lower.contains('bescom')) return 'BESCOM Electricity';
    if (lower.contains('tangedco')) return 'TANGEDCO Electricity';
    if (lower.contains('jio')) return 'Jio Recharge';
    if (lower.contains('airtel')) return 'Airtel';

    return cleaned;
  }

  /// Searches the local SQLite database for past expenses or incomes from this merchant/shop.
  /// Returns the historical category and payment method chosen by the user.
  Future<MerchantHistoricalMatch?> findHistoricalCategory(String merchantName, {bool isIncome = false}) async {
    if (merchantName.trim().isEmpty) return null;

    try {
      final db = await AppDatabase.instance.database;
      final normalized = normalizeMerchantName(merchantName).trim();
      final queryParam = '%$normalized%';

      if (isIncome) {
        // Query income table for past sources
        final results = await db.rawQuery('''
          SELECT categoryId, paymentMethod, source, COUNT(*) as freq
          FROM income
          WHERE source LIKE ? OR notes LIKE ?
          GROUP BY categoryId, paymentMethod
          ORDER BY freq DESC, createdAt DESC
          LIMIT 1
        ''', [queryParam, queryParam]);

        if (results.isNotEmpty) {
          final row = results.first;
          return MerchantHistoricalMatch(
            incomeSource: row['categoryId'] as String?,
            paymentMethod: row['paymentMethod'] as String?,
            frequency: (row['freq'] as num?)?.toInt() ?? 1,
            matchedMerchant: (row['source'] as String?) ?? normalized,
          );
        }
      } else {
        // Query expenses table for past locations/merchants
        final results = await db.rawQuery('''
          SELECT categoryId, paymentMethod, location, COUNT(*) as freq
          FROM expenses
          WHERE location LIKE ? OR notes LIKE ?
          GROUP BY categoryId, paymentMethod
          ORDER BY freq DESC, createdAt DESC
          LIMIT 1
        ''', [queryParam, queryParam]);

        if (results.isNotEmpty) {
          final row = results.first;
          return MerchantHistoricalMatch(
            categoryId: row['categoryId'] as String?,
            paymentMethod: row['paymentMethod'] as String?,
            frequency: (row['freq'] as num?)?.toInt() ?? 1,
            matchedMerchant: (row['location'] as String?) ?? normalized,
          );
        }
      }
    } catch (_) {
      // Fallback gracefully if database table is not initialized or query fails
    }

    return null;
  }

  /// Groups detected payments by merchant/shop and calculates spend totals & counts
  List<MerchantSpendingGroup> calculateMerchantSummary(List<DetectedPayment> payments) {
    final Map<String, List<DetectedPayment>> grouped = {};

    for (final p in payments) {
      final name = normalizeMerchantName(p.merchant ?? (p.isIncome ? 'Income' : 'General'));
      grouped.putIfAbsent(name, () => []).add(p);
    }

    final List<MerchantSpendingGroup> summaries = [];

    grouped.forEach((merchantName, list) {
      double total = 0.0;
      int validCount = 0;
      bool isIncomeGroup = list.isNotEmpty && list.first.isIncome;

      for (final item in list) {
        if (item.amount != null && item.amount! > 0) {
          total += item.amount!;
          validCount++;
        }
      }

      if (validCount > 0) {
        summaries.add(
          MerchantSpendingGroup(
            merchantName: merchantName,
            totalAmount: total,
            count: validCount,
            averageAmount: total / validCount,
            payments: list,
            isIncome: isIncomeGroup,
          ),
        );
      }
    });

    // Sort by total amount descending
    summaries.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return summaries;
  }
}
