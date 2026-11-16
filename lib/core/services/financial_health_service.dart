class FinancialHealthMetrics {
  final double score; // 0 to 100
  final String status; // Critical, Warning, Good, Excellent
  final double savingsRate;
  final double debtRatio;
  final double emergencyFundMonths;
  final double investmentRatio;

  FinancialHealthMetrics({
    required this.score,
    required this.status,
    required this.savingsRate,
    required this.debtRatio,
    required this.emergencyFundMonths,
    required this.investmentRatio,
  });
}

class FinancialHealthService {
  static FinancialHealthMetrics calculate({
    required double monthlyIncome,
    required double monthlyExpenses,
    required double totalDebtPayments,
    required double liquidSavings,
    required double totalInvestments,
  }) {
    if (monthlyIncome <= 0) {
      return FinancialHealthMetrics(
        score: 40.0,
        status: 'Warning',
        savingsRate: 0,
        debtRatio: 0,
        emergencyFundMonths: 0,
        investmentRatio: 0,
      );
    }

    final netSavings = monthlyIncome - monthlyExpenses;
    final savingsRate = (netSavings / monthlyIncome).clamp(0.0, 1.0);
    final debtRatio = (totalDebtPayments / monthlyIncome).clamp(0.0, 1.0);
    final emergencyFundMonths = monthlyExpenses > 0 ? liquidSavings / monthlyExpenses : 12.0;
    final investmentRatio = (totalInvestments / (monthlyIncome * 12)).clamp(0.0, 1.0);

    // Score calculations
    double savingsScore = savingsRate * 30; // Max 30 pts
    double debtScore = (1.0 - debtRatio) * 25; // Max 25 pts
    double efScore = (emergencyFundMonths / 6.0).clamp(0.0, 1.0) * 25; // Max 25 pts
    double investScore = investmentRatio * 20; // Max 20 pts

    double totalScore = (savingsScore + debtScore + efScore + investScore).clamp(0.0, 100.0);

    String status = 'Critical';
    if (totalScore >= 70) {
      status = 'Excellent';
    } else if (totalScore >= 50) {
      status = 'Good';
    } else if (totalScore >= 30) {
      status = 'Warning';
    }

    return FinancialHealthMetrics(
      score: totalScore,
      status: status,
      savingsRate: savingsRate,
      debtRatio: debtRatio,
      emergencyFundMonths: emergencyFundMonths,
      investmentRatio: investmentRatio,
    );
  }
}
