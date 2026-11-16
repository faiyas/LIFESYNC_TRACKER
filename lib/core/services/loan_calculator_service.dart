import 'dart:math';

class LoanPaymentScheduleItem {
  final int month;
  final double emi;
  final double principalPayment;
  final double interestPayment;
  final double remainingBalance;

  LoanPaymentScheduleItem({
    required this.month,
    required this.emi,
    required this.principalPayment,
    required this.interestPayment,
    required this.remainingBalance,
  });
}

class LoanCalculatorService {
  static double calculateEmi({
    required double principal,
    required double annualInterestRate,
    required int tenureMonths,
  }) {
    if (principal <= 0 || tenureMonths <= 0) return 0;
    if (annualInterestRate <= 0) return principal / tenureMonths;

    final monthlyRate = annualInterestRate / 12 / 100;
    final emi = (principal * monthlyRate * pow(1 + monthlyRate, tenureMonths)) /
        (pow(1 + monthlyRate, tenureMonths) - 1);
    return emi;
  }

  static List<LoanPaymentScheduleItem> generateAmortizationSchedule({
    required double principal,
    required double annualInterestRate,
    required int tenureMonths,
    double extraPaymentPerMonth = 0.0,
  }) {
    final schedule = <LoanPaymentScheduleItem>[];
    if (principal <= 0 || tenureMonths <= 0) return schedule;

    final emi = calculateEmi(
      principal: principal,
      annualInterestRate: annualInterestRate,
      tenureMonths: tenureMonths,
    );

    double balance = principal;
    final monthlyRate = annualInterestRate / 12 / 100;

    for (int month = 1; month <= tenureMonths && balance > 0; month++) {
      final interestPayment = balance * monthlyRate;
      double principalPayment = (emi - interestPayment) + extraPaymentPerMonth;

      if (principalPayment > balance) {
        principalPayment = balance;
      }

      balance -= principalPayment;
      if (balance < 0) balance = 0;

      schedule.add(
        LoanPaymentScheduleItem(
          month: month,
          emi: principalPayment + interestPayment,
          principalPayment: principalPayment,
          interestPayment: interestPayment,
          remainingBalance: balance,
        ),
      );
    }

    return schedule;
  }
}
