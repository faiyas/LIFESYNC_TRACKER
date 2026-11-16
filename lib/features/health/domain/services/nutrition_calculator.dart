import '../../data/models/health_models.dart';

class NutritionCalculator {
  /// Calculate scaled nutrition based on custom quantity and serving size
  static Map<String, double> scaleNutrition({
    required FoodItem food,
    required double quantity,
  }) {
    if (food.servingSize <= 0) {
      return {
        'calories': 0.0,
        'protein': 0.0,
        'carbs': 0.0,
        'fat': 0.0,
        'fiber': 0.0,
      };
    }

    final multiplier = quantity / food.servingSize;

    return {
      'calories': double.parse((food.calories * multiplier).toStringAsFixed(1)),
      'protein': double.parse((food.protein * multiplier).toStringAsFixed(1)),
      'carbs': double.parse((food.carbs * multiplier).toStringAsFixed(1)),
      'fat': double.parse((food.fat * multiplier).toStringAsFixed(1)),
      'fiber': double.parse((food.fiber * multiplier).toStringAsFixed(1)),
    };
  }

  /// Sum up nutrition totals from a list of FoodLogs
  static Map<String, double> calculateDailyNutritionTotals(List<FoodLog> logs) {
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;
    double totalFiber = 0.0;

    for (final log in logs) {
      totalCalories += log.calories;
      totalProtein += log.protein;
      totalCarbs += log.carbs;
      totalFat += log.fat;
      totalFiber += log.fiber;
    }

    return {
      'calories': double.parse(totalCalories.toStringAsFixed(1)),
      'protein': double.parse(totalProtein.toStringAsFixed(1)),
      'carbs': double.parse(totalCarbs.toStringAsFixed(1)),
      'fat': double.parse(totalFat.toStringAsFixed(1)),
      'fiber': double.parse(totalFiber.toStringAsFixed(1)),
    };
  }

  /// Calculate totals by meal type ('Breakfast', 'Lunch', 'Dinner', 'Snack')
  static Map<String, double> calculateMealCalories(List<FoodLog> logs) {
    final mealTotals = <String, double>{
      'Breakfast': 0.0,
      'Lunch': 0.0,
      'Dinner': 0.0,
      'Snack': 0.0,
    };

    for (final log in logs) {
      final key = log.mealType.trim();
      mealTotals[key] = (mealTotals[key] ?? 0.0) + log.calories;
    }

    return mealTotals;
  }
}
