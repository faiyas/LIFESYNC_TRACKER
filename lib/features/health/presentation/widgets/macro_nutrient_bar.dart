import 'package:flutter/material.dart';

class MacroNutrientBar extends StatelessWidget {
  final double consumedProtein;
  final double targetProtein;
  final double consumedCarbs;
  final double targetCarbs;
  final double consumedFat;
  final double targetFat;
  final double consumedFiber;
  final double targetFiber;

  const MacroNutrientBar({
    super.key,
    required this.consumedProtein,
    required this.targetProtein,
    required this.consumedCarbs,
    required this.targetCarbs,
    required this.consumedFat,
    required this.targetFat,
    required this.consumedFiber,
    required this.targetFiber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
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
          const Text(
            'Macronutrients',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMacroItem(
                  context,
                  label: 'Protein',
                  consumed: consumedProtein,
                  target: targetProtein,
                  color: const Color(0xFFEF4444), // Coral Red
                  icon: Icons.fitness_center_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMacroItem(
                  context,
                  label: 'Carbs',
                  consumed: consumedCarbs,
                  target: targetCarbs,
                  color: const Color(0xFFF59E0B), // Amber
                  icon: Icons.grain_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMacroItem(
                  context,
                  label: 'Fat',
                  consumed: consumedFat,
                  target: targetFat,
                  color: const Color(0xFF8B5CF6), // Purple
                  icon: Icons.opacity_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMacroItem(
                  context,
                  label: 'Fiber',
                  consumed: consumedFiber,
                  target: targetFiber,
                  color: const Color(0xFF10B981), // Emerald
                  icon: Icons.eco_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(
    BuildContext context, {
    required String label,
    required double consumed,
    required double target,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: consumed.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                TextSpan(
                  text: ' / ${target.toStringAsFixed(0)} g',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}
