import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync_tracker/core/services/loan_calculator_service.dart';

void main() {
  group('LoanCalculatorService Tests', () {
    test('Calculate EMI correctly for standard loan', () {
      final emi = LoanCalculatorService.calculateEmi(
        principal: 10000,
        annualInterestRate: 10,
        tenureMonths: 12,
      );

      // Standard EMI for $10,000 at 10% for 12 months is approx $879.16
      expect(emi, greaterThan(870));
      expect(emi, lessThan(890));
    });

    test('Amortization schedule generates correct number of payments', () {
      final schedule = LoanCalculatorService.generateAmortizationSchedule(
        principal: 12000,
        annualInterestRate: 12,
        tenureMonths: 12,
      );

      expect(schedule.length, equals(12));
      expect(schedule.last.remainingBalance, closeTo(0.0, 0.001));
    });
  });
}
