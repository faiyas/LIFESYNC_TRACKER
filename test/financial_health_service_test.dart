import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync_tracker/core/services/financial_health_service.dart';

void main() {
  group('FinancialHealthService Tests', () {
    test('Calculate score for healthy financial status', () {
      final health = FinancialHealthService.calculate(
        monthlyIncome: 10000,
        monthlyExpenses: 4000,
        totalDebtPayments: 1000,
        liquidSavings: 24000,
        totalInvestments: 50000,
      );

      expect(health.score, greaterThanOrEqualTo(70.0));
      expect(health.status, equals('Excellent'));
      expect(health.savingsRate, equals(0.6));
    });
  });
}
