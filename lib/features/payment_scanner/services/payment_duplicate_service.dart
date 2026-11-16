import '../../../database/app_database.dart';
import '../../../models/models.dart';

class PaymentDuplicateService {
  /// Checks whether a transaction ID already exists in expenses or income
  static Future<bool> hasTransactionId(String transactionId) async {
    if (transactionId.isEmpty) return false;
    final db = await AppDatabase.instance.database;
    final expRes = await db.query(
      'expenses',
      where: 'notes LIKE ?',
      whereArgs: ['%$transactionId%'],
      limit: 1,
    );
    if (expRes.isNotEmpty) return true;

    final incRes = await db.query(
      'income',
      where: 'notes LIKE ?',
      whereArgs: ['%$transactionId%'],
      limit: 1,
    );
    return incRes.isNotEmpty;
  }

  static Future<Expense?> findByTransactionId(String transactionId) async {
    if (transactionId.isEmpty) return null;
    final db = await AppDatabase.instance.database;
    final res = await db.query(
      'expenses',
      where: 'notes LIKE ?',
      whereArgs: ['%$transactionId%'],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return Expense.fromMap(res.first);
    }
    return null;
  }

  static Future<Expense?> findSimilarExpense({
    required double amount,
    required String dateStr,
    String? merchant,
  }) async {
    final db = await AppDatabase.instance.database;
    final res = await db.query(
      'expenses',
      where: 'amount = ? AND date = ?',
      whereArgs: [amount, dateStr],
    );

    if (res.isEmpty) return null;

    if (merchant != null && merchant.isNotEmpty) {
      final merchantLower = merchant.toLowerCase();
      for (final map in res) {
        final exp = Expense.fromMap(map);
        if (exp.location != null && exp.location!.toLowerCase().contains(merchantLower)) {
          return exp;
        }
      }
      // If merchant was specified but did not match any entry, it's NOT a duplicate
      return null;
    }
    return Expense.fromMap(res.first);
  }

  static Future<Income?> findSimilarIncome({
    required double amount,
    required String dateStr,
    String? source,
  }) async {
    final db = await AppDatabase.instance.database;
    final res = await db.query(
      'income',
      where: 'amount = ? AND date = ?',
      whereArgs: [amount, dateStr],
    );

    if (res.isEmpty) return null;

    if (source != null && source.isNotEmpty) {
      final sourceLower = source.toLowerCase();
      for (final map in res) {
        final inc = Income.fromMap(map);
        if (inc.source.toLowerCase().contains(sourceLower) ||
            (inc.notes != null && inc.notes!.toLowerCase().contains(sourceLower))) {
          return inc;
        }
      }
      return null;
    }
    return Income.fromMap(res.first);
  }

  static Future<bool> isDuplicate({
    String? transactionId,
    double? amount,
    String? dateStr,
    String? merchant,
    bool isIncome = false,
  }) async {
    if (transactionId != null && transactionId.isNotEmpty) {
      final hasTxn = await hasTransactionId(transactionId);
      if (hasTxn) return true;
    }

    if (amount != null && dateStr != null && dateStr.isNotEmpty) {
      if (isIncome) {
        final match = await findSimilarIncome(
          amount: amount,
          dateStr: dateStr,
          source: merchant,
        );
        if (match != null) return true;
      } else {
        final match = await findSimilarExpense(
          amount: amount,
          dateStr: dateStr,
          merchant: merchant,
        );
        if (match != null) return true;
      }
    }

    return false;
  }
}

