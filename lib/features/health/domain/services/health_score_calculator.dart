class HealthScoreResult {
  final int totalScore; // 0 - 100
  final double calorieScore; // 0 - 100
  final double proteinScore; // 0 - 100
  final double stepScore; // 0 - 100
  final double waterScore; // 0 - 100
  final double loggingScore; // 0 - 100
  final bool calorieCompleted;
  final bool proteinCompleted;
  final bool stepCompleted;
  final bool waterCompleted;
  final bool loggingCompleted;

  const HealthScoreResult({
    required this.totalScore,
    required this.calorieScore,
    required this.proteinScore,
    required this.stepScore,
    required this.waterScore,
    required this.loggingScore,
    required this.calorieCompleted,
    required this.proteinCompleted,
    required this.stepCompleted,
    required this.waterCompleted,
    required this.loggingCompleted,
  });
}

class HealthScoreCalculator {
  static HealthScoreResult calculate({
    required double caloriesConsumed,
    required double calorieTarget,
    required double proteinConsumed,
    required double proteinTarget,
    required int stepsTaken,
    required int stepGoal,
    required int waterConsumedMl,
    required int waterGoalMl,
    required int loggedMealsCount,
  }) {
    // 1. Calories (Weight 30%)
    double calScore = 0.0;
    if (calorieTarget > 0) {
      final ratio = caloriesConsumed / calorieTarget;
      if (ratio >= 0.85 && ratio <= 1.15) {
        calScore = 100.0;
      } else if (ratio < 0.85) {
        calScore = (ratio / 0.85) * 100.0;
      } else {
        // Over target
        final overRatio = (ratio - 1.15);
        calScore = (100.0 - (overRatio * 100.0)).clamp(30.0, 100.0);
      }
    }
    calScore = calScore.clamp(0.0, 100.0);
    final calorieCompleted = calScore >= 80.0;

    // 2. Protein (Weight 20%)
    double protScore = 0.0;
    if (proteinTarget > 0) {
      protScore = ((proteinConsumed / proteinTarget) * 100.0).clamp(0.0, 100.0);
    }
    final proteinCompleted = protScore >= 80.0;

    // 3. Steps (Weight 25%)
    double stepSc = 0.0;
    if (stepGoal > 0) {
      stepSc = ((stepsTaken / stepGoal) * 100.0).clamp(0.0, 100.0);
    }
    final stepCompleted = stepSc >= 80.0;

    // 4. Water (Weight 15%)
    double waterSc = 0.0;
    if (waterGoalMl > 0) {
      waterSc = ((waterConsumedMl / waterGoalMl) * 100.0).clamp(0.0, 100.0);
    }
    final waterCompleted = waterSc >= 80.0;

    // 5. Food Logging Consistency (Weight 10%)
    // Logged at least 3 distinct meals/snacks
    double logSc = ((loggedMealsCount / 3.0) * 100.0).clamp(0.0, 100.0);
    final loggingCompleted = loggedMealsCount >= 3;

    // Weighted total score
    final total = (calScore * 0.30) +
        (protScore * 0.20) +
        (stepSc * 0.25) +
        (waterSc * 0.15) +
        (logSc * 0.10);

    return HealthScoreResult(
      totalScore: total.round().clamp(0, 100),
      calorieScore: calScore,
      proteinScore: protScore,
      stepScore: stepSc,
      waterScore: waterSc,
      loggingScore: logSc,
      calorieCompleted: calorieCompleted,
      proteinCompleted: proteinCompleted,
      stepCompleted: stepCompleted,
      waterCompleted: waterCompleted,
      loggingCompleted: loggingCompleted,
    );
  }
}
