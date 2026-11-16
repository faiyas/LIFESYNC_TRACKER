import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/health_models.dart';
import '../controllers/health_controller.dart';
import '../widgets/calorie_radial_gauge.dart';
import '../widgets/macro_nutrient_bar.dart';
import '../widgets/meal_card.dart';
import '../widgets/food_timeline_view.dart';
import '../widgets/water_intake_card.dart';
import '../widgets/daily_health_score_card.dart';
import '../widgets/smart_daily_summary_card.dart';
import '../widgets/add_food_bottom_sheet.dart';
import 'health_profile_page.dart';
import 'food_search_page.dart';
import 'step_counter_page.dart';
import 'water_tracker_page.dart';
import 'weight_tracker_page.dart';
import 'health_progress_page.dart';
import 'food_history_page.dart';

class HealthDashboardPage extends ConsumerWidget {
  const HealthDashboardPage({super.key});

  void _showEditLogQuantityDialog(BuildContext context, WidgetRef ref, FoodLog log) {
    final qtyCtrl = TextEditingController(text: log.quantity.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${log.foodName}'),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Quantity',
            suffixText: log.servingUnit,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newQty = double.tryParse(qtyCtrl.text.trim());
              if (newQty != null && newQty > 0 && log.quantity > 0) {
                Navigator.pop(ctx);
                final ratio = newQty / log.quantity;
                final updated = log.copyWith(
                  quantity: newQty,
                  calories: double.parse((log.calories * ratio).toStringAsFixed(1)),
                  protein: double.parse((log.protein * ratio).toStringAsFixed(1)),
                  carbs: double.parse((log.carbs * ratio).toStringAsFixed(1)),
                  fat: double.parse((log.fat * ratio).toStringAsFixed(1)),
                  fiber: double.parse((log.fiber * ratio).toStringAsFixed(1)),
                );
                ref.read(healthControllerProvider.notifier).updateFoodLog(updated);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(healthControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    DateTime currentDate = DateTime.tryParse(healthState.selectedDate) ?? DateTime.now();
    final isToday = healthState.selectedDate == DateFormat('yyyy-MM-dd').format(DateTime.now());

    final breakfastLogs = healthState.foodLogs.where((l) => l.mealType.toLowerCase() == 'breakfast').toList();
    final lunchLogs = healthState.foodLogs.where((l) => l.mealType.toLowerCase() == 'lunch').toList();
    final dinnerLogs = healthState.foodLogs.where((l) => l.mealType.toLowerCase() == 'dinner').toList();
    final snackLogs = healthState.foodLogs.where((l) => l.mealType.toLowerCase() == 'snack').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Text('Health & Diet Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Food Database',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodSearchPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.insights_rounded),
            tooltip: 'Weekly Progress',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthProgressPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Food History',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodHistoryPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Your Health Goals',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthProfilePage()));
            },
          ),
        ],
      ),
      body: healthState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(healthControllerProvider.notifier).loadAllData(),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Date Navigation Bar
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () {
                            final prev = currentDate.subtract(const Duration(days: 1));
                            ref.read(healthControllerProvider.notifier).changeDate(prev);
                          },
                        ),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: currentDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              ref.read(healthControllerProvider.notifier).changeDate(picked);
                            }
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0284C7)),
                              const SizedBox(width: 8),
                              Text(
                                isToday ? 'Today, ${DateFormat('dd MMM').format(currentDate)}' : DateFormat('EEEE, dd MMM yyyy').format(currentDate),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () {
                            final next = currentDate.add(const Duration(days: 1));
                            ref.read(healthControllerProvider.notifier).changeDate(next);
                          },
                        ),
                      ],
                    ),
                  ),

                  // 1. Calories Radial Gauge
                  CalorieRadialGauge(
                    consumedCalories: healthState.totalCalories,
                    targetCalories: healthState.profile.dailyCalorieTarget,
                    remainingCalories: healthState.remainingCalories,
                  ),
                  const SizedBox(height: 16),

                  // 2. Macronutrient Progress Bar
                  MacroNutrientBar(
                    consumedProtein: healthState.totalProtein,
                    targetProtein: healthState.profile.proteinTarget,
                    consumedCarbs: healthState.totalCarbs,
                    targetCarbs: healthState.profile.carbsTarget,
                    consumedFat: healthState.totalFat,
                    targetFat: healthState.profile.fatTarget,
                    consumedFiber: healthState.totalFiber,
                    targetFiber: healthState.profile.fiberTarget,
                  ),
                  const SizedBox(height: 16),

                  // 3. Quick Cards Row: Step Counter & Weight Tracker
                  Row(
                    children: [
                      // Steps card
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StepCounterPage()));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.directions_walk_rounded, color: Color(0xFF10B981), size: 20),
                                    Spacer(),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${healthState.liveSteps}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  '/ ${healthState.profile.dailyStepGoal} steps',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Weight card
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const WeightTrackerPage()));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.monitor_weight_outlined, color: Color(0xFF8B5CF6), size: 20),
                                    Spacer(),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${healthState.latestWeight?.weightKg ?? healthState.profile.weightKg} kg',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                                const Text(
                                  'Weight Tracker',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Water Intake Tracker Card
                  WaterIntakeCard(
                    totalWaterMl: healthState.totalWaterMl,
                    waterGoalMl: healthState.profile.dailyWaterGoal,
                    onAddWater: (ml) => ref.read(healthControllerProvider.notifier).logWater(ml),
                    onUndoWater: () => ref.read(healthControllerProvider.notifier).undoWater(),
                    onCustomWater: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const WaterTrackerPage()));
                    },
                  ),

                  // 5. Daily Meals Section (Breakfast, Lunch, Dinner, Snacks)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Today\'s Meals', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),

                  MealCard(
                    mealType: 'Breakfast',
                    logs: breakfastLogs,
                    totalCalories: healthState.mealCalories['Breakfast'] ?? 0.0,
                    onAddFood: () {
                      AddFoodBottomSheet.show(
                        context,
                        initialMealType: 'Breakfast',
                        selectedDate: healthState.selectedDate,
                        allFoods: healthState.allFoods,
                        favoriteFoods: healthState.favoriteFoods,
                        recentFoods: healthState.recentFoods,
                        onAddFood: (log) => ref.read(healthControllerProvider.notifier).addFoodLog(log),
                        onToggleFavorite: (id, fav) => ref.read(healthControllerProvider.notifier).toggleFavoriteFood(id, fav),
                      );
                    },
                    onEditFood: (log) => _showEditLogQuantityDialog(context, ref, log),
                    onDeleteFood: (id) => ref.read(healthControllerProvider.notifier).deleteFoodLog(id),
                  ),

                  MealCard(
                    mealType: 'Lunch',
                    logs: lunchLogs,
                    totalCalories: healthState.mealCalories['Lunch'] ?? 0.0,
                    onAddFood: () {
                      AddFoodBottomSheet.show(
                        context,
                        initialMealType: 'Lunch',
                        selectedDate: healthState.selectedDate,
                        allFoods: healthState.allFoods,
                        favoriteFoods: healthState.favoriteFoods,
                        recentFoods: healthState.recentFoods,
                        onAddFood: (log) => ref.read(healthControllerProvider.notifier).addFoodLog(log),
                        onToggleFavorite: (id, fav) => ref.read(healthControllerProvider.notifier).toggleFavoriteFood(id, fav),
                      );
                    },
                    onEditFood: (log) => _showEditLogQuantityDialog(context, ref, log),
                    onDeleteFood: (id) => ref.read(healthControllerProvider.notifier).deleteFoodLog(id),
                  ),

                  MealCard(
                    mealType: 'Dinner',
                    logs: dinnerLogs,
                    totalCalories: healthState.mealCalories['Dinner'] ?? 0.0,
                    onAddFood: () {
                      AddFoodBottomSheet.show(
                        context,
                        initialMealType: 'Dinner',
                        selectedDate: healthState.selectedDate,
                        allFoods: healthState.allFoods,
                        favoriteFoods: healthState.favoriteFoods,
                        recentFoods: healthState.recentFoods,
                        onAddFood: (log) => ref.read(healthControllerProvider.notifier).addFoodLog(log),
                        onToggleFavorite: (id, fav) => ref.read(healthControllerProvider.notifier).toggleFavoriteFood(id, fav),
                      );
                    },
                    onEditFood: (log) => _showEditLogQuantityDialog(context, ref, log),
                    onDeleteFood: (id) => ref.read(healthControllerProvider.notifier).deleteFoodLog(id),
                  ),

                  MealCard(
                    mealType: 'Snack',
                    logs: snackLogs,
                    totalCalories: healthState.mealCalories['Snack'] ?? 0.0,
                    onAddFood: () {
                      AddFoodBottomSheet.show(
                        context,
                        initialMealType: 'Snack',
                        selectedDate: healthState.selectedDate,
                        allFoods: healthState.allFoods,
                        favoriteFoods: healthState.favoriteFoods,
                        recentFoods: healthState.recentFoods,
                        onAddFood: (log) => ref.read(healthControllerProvider.notifier).addFoodLog(log),
                        onToggleFavorite: (id, fav) => ref.read(healthControllerProvider.notifier).toggleFavoriteFood(id, fav),
                      );
                    },
                    onEditFood: (log) => _showEditLogQuantityDialog(context, ref, log),
                    onDeleteFood: (id) => ref.read(healthControllerProvider.notifier).deleteFoodLog(id),
                  ),

                  // 6. Food Timeline View
                  FoodTimelineView(
                    logs: healthState.foodLogs,
                    onEdit: (log) => _showEditLogQuantityDialog(context, ref, log),
                    onDelete: (id) => ref.read(healthControllerProvider.notifier).deleteFoodLog(id),
                  ),

                  // 7. Daily Health Score
                  DailyHealthScoreCard(scoreResult: healthState.healthScore),

                  // 8. Smart Daily Summary
                  SmartDailySummaryCard(
                    caloriesConsumed: healthState.totalCalories,
                    calorieTarget: healthState.profile.dailyCalorieTarget,
                    stepsTaken: healthState.liveSteps,
                    stepGoal: healthState.profile.dailyStepGoal,
                    proteinConsumed: healthState.totalProtein,
                    waterConsumedMl: healthState.totalWaterMl,
                  ),
                ],
              ),
            ),
    );
  }
}
