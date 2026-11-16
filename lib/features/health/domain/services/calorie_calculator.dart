class CalorieCalculator {
  /// Calculate Basal Metabolic Rate (BMR) using Mifflin-St Jeor Equation
  static double calculateBMR({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
  }) {
    if (gender.toLowerCase() == 'female') {
      return (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * age) - 161.0;
    } else {
      // Default male / other
      return (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * age) + 5.0;
    }
  }

  /// Get activity multiplier factor
  static double getActivityFactor(String activityLevel) {
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
        return 1.2;
      case 'lightly_active':
      case 'light':
        return 1.375;
      case 'moderately_active':
      case 'moderate':
        return 1.55;
      case 'very_active':
      case 'active':
        return 1.725;
      default:
        return 1.375;
    }
  }

  /// Calculate Total Daily Energy Expenditure (TDEE)
  static double calculateTDEE({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
    required String activityLevel,
  }) {
    final bmr = calculateBMR(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
    );
    final factor = getActivityFactor(activityLevel);
    return bmr * factor;
  }

  /// Calculate target calories based on goal with moderate deficit/surplus
  static double calculateDailyTarget({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
    required String activityLevel,
    required String goal,
  }) {
    final tdee = calculateTDEE(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
      activityLevel: activityLevel,
    );

    double target;
    switch (goal.toLowerCase()) {
      case 'lose_weight':
      case 'lose':
        // Moderate healthy deficit of 400 kcal
        target = tdee - 400.0;
        final minCal = gender.toLowerCase() == 'female' ? 1200.0 : 1500.0;
        if (target < minCal) target = minCal;
        break;
      case 'gain_weight':
      case 'gain':
        // Moderate clean surplus of 350 kcal
        target = tdee + 350.0;
        break;
      case 'maintain_weight':
      case 'maintain':
      default:
        target = tdee;
        break;
    }

    return (target / 10).round() * 10.0; // Round to nearest 10
  }

  /// Calculate Macro Nutrient targets in grams
  static Map<String, double> calculateMacroTargets({
    required double dailyCalories,
    required double weightKg,
    required String goal,
  }) {
    // Protein: 1.8g to 2.2g per kg for weight loss/gain, 1.6g for maintenance
    double proteinMultiplier = 1.6;
    if (goal.toLowerCase() == 'lose_weight') {
      proteinMultiplier = 2.0; // Higher protein preserves muscle in deficit
    } else if (goal.toLowerCase() == 'gain_weight') {
      proteinMultiplier = 1.8;
    }

    double proteinGrams = (weightKg * proteinMultiplier).clamp(50.0, 220.0);
    double proteinCalories = proteinGrams * 4.0;

    // Fat: ~25% to 30% of total calories
    double fatCalories = dailyCalories * 0.25;
    double fatGrams = (fatCalories / 9.0).clamp(30.0, 100.0);

    // Carbs: Remaining calories
    double remainingCalories = dailyCalories - proteinCalories - (fatGrams * 9.0);
    double carbsGrams = (remainingCalories / 4.0).clamp(50.0, 400.0);

    // Fiber: ~14g per 1000 kcal
    double fiberGrams = ((dailyCalories / 1000.0) * 14.0).clamp(20.0, 45.0);

    return {
      'protein': double.parse(proteinGrams.toStringAsFixed(1)),
      'carbs': double.parse(carbsGrams.toStringAsFixed(1)),
      'fat': double.parse(fatGrams.toStringAsFixed(1)),
      'fiber': double.parse(fiberGrams.toStringAsFixed(1)),
    };
  }
}
