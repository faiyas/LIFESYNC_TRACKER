import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/health_controller.dart';

class HomeHealthSummaryCard extends ConsumerWidget {
  const HomeHealthSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(healthControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final calConsumed = state.totalCalories.toStringAsFixed(0);
    final calTarget = state.profile.dailyCalorieTarget.toStringAsFixed(0);
    final steps = state.liveSteps;
    final stepGoal = state.profile.dailyStepGoal;
    final waterL = (state.totalWaterMl / 1000).toStringAsFixed(1);
    final waterGoalL = (state.profile.dailyWaterGoal / 1000).toStringAsFixed(1);
    final proteinG = state.totalProtein.toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F33) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF0284C7).withOpacity(0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite_rounded, color: Color(0xFF0284C7), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Today\'s Health',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  context.push('/health');
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('View Health', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  foregroundColor: const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 stats grid
          Row(
            children: [
              Expanded(
                child: _buildMetricPill(
                  icon: '🔥',
                  label: 'Calories',
                  value: '$calConsumed / $calTarget',
                  unit: 'kcal',
                  color: const Color(0xFFF97316),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricPill(
                  icon: '🚶',
                  label: 'Steps',
                  value: '$steps / $stepGoal',
                  unit: 'steps',
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricPill(
                  icon: '💧',
                  label: 'Water',
                  value: '$waterL / $waterGoalL',
                  unit: 'L',
                  color: const Color(0xFF0284C7),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricPill(
                  icon: '🥩',
                  label: 'Protein',
                  value: '$proteinG / ${state.profile.proteinTarget.toStringAsFixed(0)}',
                  unit: 'g',
                  color: const Color(0xFFEF4444),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required String icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
