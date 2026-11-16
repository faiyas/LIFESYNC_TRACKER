import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync_tracker/features/health/data/models/health_models.dart';
import 'package:lifesync_tracker/features/health/domain/services/calorie_calculator.dart';
import 'package:lifesync_tracker/features/health/domain/services/nutrition_calculator.dart';
import 'package:lifesync_tracker/features/health/domain/services/step_calculator.dart';
import 'package:lifesync_tracker/features/health/domain/services/health_score_calculator.dart';
import 'package:lifesync_tracker/features/health/domain/services/water_calculator.dart';
import 'package:lifesync_tracker/features/health/domain/services/weight_progress_calculator.dart';

void main() {
  group('Health & Calorie Calculations', () {
    test('BMR calculation for male and female', () {
      // Male: 10 * 70 + 6.25 * 175 - 5 * 25 + 5 = 700 + 1093.75 - 125 + 5 = 1673.75
      final maleBMR = CalorieCalculator.calculateBMR(weightKg: 70, heightCm: 175, age: 25, gender: 'male');
      expect(maleBMR, closeTo(1673.75, 0.1));

      // Female: 10 * 60 + 6.25 * 165 - 5 * 25 - 161 = 600 + 1031.25 - 125 - 161 = 1345.25
      final femaleBMR = CalorieCalculator.calculateBMR(weightKg: 60, heightCm: 165, age: 25, gender: 'female');
      expect(femaleBMR, closeTo(1345.25, 0.1));
    });

    test('TDEE calculation with activity factors', () {
      final tdee = CalorieCalculator.calculateTDEE(
        weightKg: 70,
        heightCm: 175,
        age: 25,
        gender: 'male',
        activityLevel: 'moderately_active',
      );
      // 1673.75 * 1.55 = 2594.31
      expect(tdee, closeTo(2594.31, 0.5));
    });

    test('Daily target calculation with deficit for weight loss', () {
      final target = CalorieCalculator.calculateDailyTarget(
        weightKg: 70,
        heightCm: 175,
        age: 25,
        gender: 'male',
        activityLevel: 'moderately_active',
        goal: 'lose_weight',
      );
      // 2594.31 - 400 = 2194.31 -> rounded to nearest 10 = 2190
      expect(target, equals(2190.0));
    });

    test('Nutrition scaling calculation', () {
      final chicken = FoodItem(
        id: 'c1',
        name: 'Chicken Breast',
        category: 'Protein',
        servingSize: 100,
        servingUnit: 'g',
        calories: 165,
        protein: 31,
        carbs: 0,
        fat: 3.6,
        fiber: 0,
      );

      final scaled = NutritionCalculator.scaleNutrition(food: chicken, quantity: 150);
      expect(scaled['calories'], equals(247.5));
      expect(scaled['protein'], equals(46.5));
      expect(scaled['fat'], equals(5.4));
    });

    test('Step calculations and milestone detection', () {
      final dist = StepCalculator.calculateDistanceKm(10000);
      expect(dist, equals(7.62));

      final calBurn = StepCalculator.calculateCaloriesBurned(10000);
      expect(calBurn, equals(400.0));

      final milestone = StepCalculator.getReachedMilestone(10050, 9900);
      expect(milestone, equals(10000));
    });

    test('Daily Health Score transparent calculation', () {
      final score = HealthScoreCalculator.calculate(
        caloriesConsumed: 1950,
        calorieTarget: 2000,
        proteinConsumed: 125,
        proteinTarget: 130,
        stepsTaken: 8500,
        stepGoal: 10000,
        waterConsumedMl: 2250,
        waterGoalMl: 2500,
        loggedMealsCount: 3,
      );

      expect(score.totalScore, greaterThanOrEqualTo(80));
      expect(score.calorieCompleted, isTrue);
      expect(score.proteinCompleted, isTrue);
      expect(score.stepCompleted, isTrue);
      expect(score.waterCompleted, isTrue);
      expect(score.loggingCompleted, isTrue);
    });

    test('Water recommended intake calculation', () {
      final water = WaterCalculator.calculateRecommendedWater(70);
      // 70 * 35 = 2450 -> rounded to nearest 250 = 2500 ml
      expect(water, equals(2500));
    });

    test('Weight Progress calculation', () {
      final logs = [
        WeightLog(date: '2026-08-10', weightKg: 75.0),
        WeightLog(date: '2026-08-15', weightKg: 74.2),
        WeightLog(date: '2026-08-18', weightKg: 73.5),
      ];

      final progress = WeightProgressCalculator.calculate(logs, 75.0);
      expect(progress.startingWeight, equals(75.0));
      expect(progress.currentWeight, equals(73.5));
      expect(progress.weightChange, equals(-1.5));
    });
  });
}
