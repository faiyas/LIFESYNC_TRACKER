import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/health_models.dart';
import '../../data/repositories/health_repository.dart';
import '../../domain/services/calorie_calculator.dart';
import '../../domain/services/health_score_calculator.dart';
import '../../domain/services/nutrition_calculator.dart';
import '../../domain/services/step_calculator.dart';
import '../../domain/services/step_sensor_service.dart';

class HealthState {
  final HealthProfile profile;
  final String selectedDate;
  final List<FoodLog> foodLogs;
  final List<WaterLog> waterLogs;
  final StepLog? stepLog;
  final WeightLog? latestWeight;
  final List<FoodItem> allFoods;
  final List<FoodItem> favoriteFoods;
  final List<FoodItem> recentFoods;
  final int totalWaterMl;
  final int liveSteps;
  final bool isLoading;
  final StepSensorStatus sensorStatus;
  final int? newlyReachedMilestone;

  // Calculated totals
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFiber;
  final double remainingCalories;
  final HealthScoreResult healthScore;
  final Map<String, double> mealCalories;

  const HealthState({
    required this.profile,
    required this.selectedDate,
    required this.foodLogs,
    required this.waterLogs,
    this.stepLog,
    this.latestWeight,
    required this.allFoods,
    required this.favoriteFoods,
    required this.recentFoods,
    required this.totalWaterMl,
    required this.liveSteps,
    required this.isLoading,
    required this.sensorStatus,
    this.newlyReachedMilestone,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalFiber,
    required this.remainingCalories,
    required this.healthScore,
    required this.mealCalories,
  });

  HealthState copyWith({
    HealthProfile? profile,
    String? selectedDate,
    List<FoodLog>? foodLogs,
    List<WaterLog>? waterLogs,
    StepLog? stepLog,
    WeightLog? latestWeight,
    List<FoodItem>? allFoods,
    List<FoodItem>? favoriteFoods,
    List<FoodItem>? recentFoods,
    int? totalWaterMl,
    int? liveSteps,
    bool? isLoading,
    StepSensorStatus? sensorStatus,
    int? newlyReachedMilestone,
    double? totalCalories,
    double? totalProtein,
    double? totalCarbs,
    double? totalFat,
    double? totalFiber,
    double? remainingCalories,
    HealthScoreResult? healthScore,
    Map<String, double>? mealCalories,
  }) {
    return HealthState(
      profile: profile ?? this.profile,
      selectedDate: selectedDate ?? this.selectedDate,
      foodLogs: foodLogs ?? this.foodLogs,
      waterLogs: waterLogs ?? this.waterLogs,
      stepLog: stepLog ?? this.stepLog,
      latestWeight: latestWeight ?? this.latestWeight,
      allFoods: allFoods ?? this.allFoods,
      favoriteFoods: favoriteFoods ?? this.favoriteFoods,
      recentFoods: recentFoods ?? this.recentFoods,
      totalWaterMl: totalWaterMl ?? this.totalWaterMl,
      liveSteps: liveSteps ?? this.liveSteps,
      isLoading: isLoading ?? this.isLoading,
      sensorStatus: sensorStatus ?? this.sensorStatus,
      newlyReachedMilestone: newlyReachedMilestone,
      totalCalories: totalCalories ?? this.totalCalories,
      totalProtein: totalProtein ?? this.totalProtein,
      totalCarbs: totalCarbs ?? this.totalCarbs,
      totalFat: totalFat ?? this.totalFat,
      totalFiber: totalFiber ?? this.totalFiber,
      remainingCalories: remainingCalories ?? this.remainingCalories,
      healthScore: healthScore ?? this.healthScore,
      mealCalories: mealCalories ?? this.mealCalories,
    );
  }
}

class HealthController extends StateNotifier<HealthState> {
  StreamSubscription<int>? _stepStreamSub;
  StreamSubscription<StepSensorStatus>? _sensorStatusSub;

  HealthController()
      : super(HealthState(
          profile: HealthProfile(),
          selectedDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          foodLogs: const [],
          waterLogs: const [],
          allFoods: const [],
          favoriteFoods: const [],
          recentFoods: const [],
          totalWaterMl: 0,
          liveSteps: 0,
          isLoading: true,
          sensorStatus: StepSensorStatus.idle,
          totalCalories: 0.0,
          totalProtein: 0.0,
          totalCarbs: 0.0,
          totalFat: 0.0,
          totalFiber: 0.0,
          remainingCalories: 2000.0,
          healthScore: HealthScoreCalculator.calculate(
            caloriesConsumed: 0,
            calorieTarget: 2000,
            proteinConsumed: 0,
            proteinTarget: 130,
            stepsTaken: 0,
            stepGoal: 10000,
            waterConsumedMl: 0,
            waterGoalMl: 2500,
            loggedMealsCount: 0,
          ),
          mealCalories: const {'Breakfast': 0.0, 'Lunch': 0.0, 'Dinner': 0.0, 'Snack': 0.0},
        )) {
    loadAllData();
    _initStepSensor();
  }

  void _initStepSensor() {
    _stepStreamSub = StepSensorService.instance.stepStream.listen((sensorSteps) {
      final isToday = state.selectedDate == DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (isToday) {
        final currentTotal = (state.stepLog?.steps ?? 0) + sensorSteps;
        final milestone = StepCalculator.getReachedMilestone(currentTotal, state.liveSteps);
        state = state.copyWith(
          liveSteps: currentTotal,
          newlyReachedMilestone: milestone,
        );
      }
    });

    _sensorStatusSub = StepSensorService.instance.statusStream.listen((status) {
      state = state.copyWith(sensorStatus: status);
    });
  }

  Future<void> loadAllData({String? date}) async {
    final targetDate = date ?? state.selectedDate;
    state = state.copyWith(isLoading: true, selectedDate: targetDate);

    try {
      final profile = await HealthRepository.getHealthProfile();
      final foodLogs = await HealthRepository.getFoodLogsByDate(targetDate);
      final waterLogs = await HealthRepository.getWaterLogsByDate(targetDate);
      final totalWater = await HealthRepository.getTodayWaterTotal(targetDate);
      final stepLog = await HealthRepository.getStepLogByDate(targetDate);
      final latestWeight = await HealthRepository.getLatestWeight();
      final allFoods = await HealthRepository.getAllFoods();
      final favFoods = await HealthRepository.getFavoriteFoods();
      final recFoods = await HealthRepository.getRecentFoods();

      final nutritionTotals = NutritionCalculator.calculateDailyNutritionTotals(foodLogs);
      final mealCalories = NutritionCalculator.calculateMealCalories(foodLogs);

      final totalCal = nutritionTotals['calories'] ?? 0.0;
      final totalProt = nutritionTotals['protein'] ?? 0.0;
      final totalCarb = nutritionTotals['carbs'] ?? 0.0;
      final totalFat = nutritionTotals['fat'] ?? 0.0;
      final totalFib = nutritionTotals['fiber'] ?? 0.0;
      final remCal = profile.dailyCalorieTarget - totalCal;

      final currentSteps = stepLog?.steps ?? state.liveSteps;

      final loggedMealsCount = mealCalories.values.where((cal) => cal > 0).length;

      final score = HealthScoreCalculator.calculate(
        caloriesConsumed: totalCal,
        calorieTarget: profile.dailyCalorieTarget,
        proteinConsumed: totalProt,
        proteinTarget: profile.proteinTarget,
        stepsTaken: currentSteps,
        stepGoal: profile.dailyStepGoal,
        waterConsumedMl: totalWater,
        waterGoalMl: profile.dailyWaterGoal,
        loggedMealsCount: loggedMealsCount,
      );

      state = state.copyWith(
        profile: profile,
        selectedDate: targetDate,
        foodLogs: foodLogs,
        waterLogs: waterLogs,
        stepLog: stepLog,
        latestWeight: latestWeight,
        allFoods: allFoods,
        favoriteFoods: favFoods,
        recentFoods: recFoods,
        totalWaterMl: totalWater,
        liveSteps: currentSteps,
        isLoading: false,
        totalCalories: totalCal,
        totalProtein: totalProt,
        totalCarbs: totalCarb,
        totalFat: totalFat,
        totalFiber: totalFib,
        remainingCalories: remCal,
        healthScore: score,
        mealCalories: mealCalories,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void changeDate(DateTime date) {
    final formatted = DateFormat('yyyy-MM-dd').format(date);
    loadAllData(date: formatted);
  }

  Future<void> updateProfile(HealthProfile updated) async {
    await HealthRepository.saveHealthProfile(updated);
    await loadAllData();
  }

  Future<void> recalculateAndSaveGoals({
    required int age,
    required String gender,
    required double heightCm,
    required double weightKg,
    required String activityLevel,
    required String goal,
    double? customCalorieTarget,
    int? customStepGoal,
    int? customWaterGoal,
  }) async {
    final calculatedCalTarget = customCalorieTarget ??
        CalorieCalculator.calculateDailyTarget(
          weightKg: weightKg,
          heightCm: heightCm,
          age: age,
          gender: gender,
          activityLevel: activityLevel,
          goal: goal,
        );

    final macros = CalorieCalculator.calculateMacroTargets(
      dailyCalories: calculatedCalTarget,
      weightKg: weightKg,
      goal: goal,
    );

    final updated = state.profile.copyWith(
      age: age,
      gender: gender,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: activityLevel,
      goal: goal,
      dailyCalorieTarget: calculatedCalTarget,
      dailyStepGoal: customStepGoal ?? 10000,
      dailyWaterGoal: customWaterGoal ?? 2500,
      proteinTarget: macros['protein'] ?? 130.0,
      carbsTarget: macros['carbs'] ?? 220.0,
      fatTarget: macros['fat'] ?? 65.0,
      fiberTarget: macros['fiber'] ?? 30.0,
    );

    await updateProfile(updated);
  }

  // ==================== FOOD LOG ACTIONS ====================

  Future<void> addFoodLog(FoodLog log) async {
    await HealthRepository.insertFoodLog(log);
    await loadAllData();
  }

  Future<void> updateFoodLog(FoodLog log) async {
    await HealthRepository.updateFoodLog(log);
    await loadAllData();
  }

  Future<void> deleteFoodLog(String id) async {
    await HealthRepository.deleteFoodLog(id);
    await loadAllData();
  }

  // ==================== WATER ACTIONS ====================

  Future<void> logWater(int amountMl) async {
    final log = WaterLog(date: state.selectedDate, amountMl: amountMl);
    await HealthRepository.insertWaterLog(log);
    await loadAllData();
  }

  Future<bool> undoWater() async {
    final success = await HealthRepository.deleteLatestWaterLog(state.selectedDate);
    if (success) {
      await loadAllData();
    }
    return success;
  }

  // ==================== STEP ACTIONS ====================

  Future<void> logSteps(int steps, {String source = 'manual'}) async {
    final log = StepLog(
      date: state.selectedDate,
      steps: steps,
      source: source,
      distanceKm: StepCalculator.calculateDistanceKm(steps),
      activeMinutes: StepCalculator.calculateActiveMinutes(steps),
      estimatedCaloriesBurned: StepCalculator.calculateCaloriesBurned(steps),
    );
    await HealthRepository.saveStepLog(log);
    await loadAllData();
  }

  // ==================== WEIGHT ACTIONS ====================

  Future<void> logWeight(double weightKg, {String? notes}) async {
    final log = WeightLog(date: state.selectedDate, weightKg: weightKg, notes: notes);
    await HealthRepository.saveWeightLog(log);
    await loadAllData();
  }

  // ==================== CUSTOM FOOD & FAVORITES ====================

  Future<void> toggleFavoriteFood(String foodId, bool isFavorite) async {
    await HealthRepository.toggleFavoriteFood(foodId, isFavorite);
    final favFoods = await HealthRepository.getFavoriteFoods();
    final allFoods = await HealthRepository.getAllFoods();
    state = state.copyWith(favoriteFoods: favFoods, allFoods: allFoods);
  }

  Future<void> addCustomFood(FoodItem food) async {
    await HealthRepository.insertCustomFood(food);
    final allFoods = await HealthRepository.getAllFoods();
    state = state.copyWith(allFoods: allFoods);
  }

  Future<void> deleteCustomFood(String foodId) async {
    await HealthRepository.deleteCustomFood(foodId);
    final allFoods = await HealthRepository.getAllFoods();
    state = state.copyWith(allFoods: allFoods);
  }

  void clearMilestoneNotification() {
    state = state.copyWith(newlyReachedMilestone: null);
  }

  @override
  void dispose() {
    _stepStreamSub?.cancel();
    _sensorStatusSub?.cancel();
    super.dispose();
  }
}

final healthControllerProvider = StateNotifierProvider<HealthController, HealthState>((ref) {
  return HealthController();
});
