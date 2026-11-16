import 'package:flutter/material.dart';

class SmartDailySummaryCard extends StatelessWidget {
  final double caloriesConsumed;
  final double calorieTarget;
  final int stepsTaken;
  final int stepGoal;
  final double proteinConsumed;
  final int waterConsumedMl;

  const SmartDailySummaryCard({
    super.key,
    required this.caloriesConsumed,
    required this.calorieTarget,
    required this.stepsTaken,
    required this.stepGoal,
    required this.proteinConsumed,
    required this.waterConsumedMl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final calPercent = calorieTarget > 0 ? ((caloriesConsumed / calorieTarget) * 100).round() : 0;
    final remainingSteps = stepGoal - stepsTaken;
    final waterInLiters = (waterConsumedMl / 1000).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6), size: 20),
              SizedBox(width: 8),
              Text(
                'Today\'s Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBullet(
            context,
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFF97316),
            text: 'You\'re at $calPercent% of your daily calorie target.',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildBullet(
            context,
            icon: Icons.directions_walk_rounded,
            iconColor: const Color(0xFF10B981),
            text: remainingSteps > 0
                ? 'You\'re $remainingSteps steps away from today\'s goal.'
                : '🔥 Daily step goal reached! Keep it up!',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildBullet(
            context,
            icon: Icons.fitness_center_rounded,
            iconColor: const Color(0xFFEF4444),
            text: 'Protein intake is currently ${proteinConsumed.toStringAsFixed(0)} g.',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildBullet(
            context,
            icon: Icons.water_drop_rounded,
            iconColor: const Color(0xFF0284C7),
            text: 'Water intake is at $waterInLiters L so far.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String text,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }
}
