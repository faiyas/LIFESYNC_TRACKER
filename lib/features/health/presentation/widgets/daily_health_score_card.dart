import 'package:flutter/material.dart';
import '../../domain/services/health_score_calculator.dart';

class DailyHealthScoreCard extends StatelessWidget {
  final HealthScoreResult scoreResult;

  const DailyHealthScoreCard({
    super.key,
    required this.scoreResult,
  });

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF10B981); // Emerald
    if (score >= 50) return const Color(0xFF0284C7); // Sky Blue
    return const Color(0xFFF59E0B); // Amber
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _getScoreColor(scoreResult.totalScore);

    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${scoreResult.totalScore}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Health Score',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Daily adherence & habits summary',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Checklist
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill(
                label: 'Calories',
                valueText: scoreResult.calorieCompleted ? '✓' : '${scoreResult.calorieScore.toStringAsFixed(0)}%',
                isCompleted: scoreResult.calorieCompleted,
                isDark: isDark,
              ),
              _buildPill(
                label: 'Protein',
                valueText: scoreResult.proteinCompleted ? '✓' : '${scoreResult.proteinScore.toStringAsFixed(0)}%',
                isCompleted: scoreResult.proteinCompleted,
                isDark: isDark,
              ),
              _buildPill(
                label: 'Steps',
                valueText: scoreResult.stepCompleted ? '✓' : '${scoreResult.stepScore.toStringAsFixed(0)}%',
                isCompleted: scoreResult.stepCompleted,
                isDark: isDark,
              ),
              _buildPill(
                label: 'Water',
                valueText: scoreResult.waterCompleted ? '✓' : '${scoreResult.waterScore.toStringAsFixed(0)}%',
                isCompleted: scoreResult.waterCompleted,
                isDark: isDark,
              ),
              _buildPill(
                label: 'Food Logging',
                valueText: scoreResult.loggingCompleted ? '✓' : '${scoreResult.loggingScore.toStringAsFixed(0)}%',
                isCompleted: scoreResult.loggingCompleted,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required String valueText,
    required bool isCompleted,
    required bool isDark,
  }) {
    final statusColor = isCompleted ? const Color(0xFF10B981) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFF10B981).withOpacity(0.12)
            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCompleted ? const Color(0xFF10B981).withOpacity(0.3) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            valueText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
