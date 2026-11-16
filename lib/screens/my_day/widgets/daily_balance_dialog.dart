import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/my_day_models.dart';
import '../../../services/app_time_service.dart';
import '../../../services/dynamic_scheduling_engine.dart';

/// Modal dialog showing the 24-hour daily balance breakdown chart & analytics
class DailyBalanceDialog extends StatelessWidget {
  final DailyScheduleResult scheduleResult;

  const DailyBalanceDialog({super.key, required this.scheduleResult});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final summaries = scheduleResult.categorySummaries.values.toList();
    final freeMins = scheduleResult.availableFlexibleMinutes;
    final sleepMins = scheduleResult.sleepMinutes;

    final List<PieChartSectionData> sections = [];

    // 1. Add category slices
    for (final s in summaries) {
      if (s.plannedMinutes > 0) {
        final pct = (s.plannedMinutes / 1440.0) * 100;
        sections.add(
          PieChartSectionData(
            color: s.color,
            value: s.plannedMinutes.toDouble(),
            title: '${pct.toStringAsFixed(0)}%',
            radius: 40,
            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        );
      }
    }

    // 2. Add Sleep slice
    if (sleepMins > 0) {
      final pct = (sleepMins / 1440.0) * 100;
      sections.add(
        PieChartSectionData(
          color: const Color(0xFF475569),
          value: sleepMins.toDouble(),
          title: '${pct.toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      );
    }

    // 3. Add Free Time slice
    if (freeMins > 0) {
      final pct = (freeMins / 1440.0) * 100;
      sections.add(
        PieChartSectionData(
          color: const Color(0xFF00F2FE),
          value: freeMins.toDouble(),
          title: '${pct.toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      );
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.pie_chart_rounded, color: Color(0xFF8B5CF6)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '24-Hour Balance Analytics',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),

              const SizedBox(height: 16),

              // Donut Chart
              SizedBox(
                height: 180,
                child: sections.isEmpty
                    ? const Center(child: Text('No activities scheduled for breakdown'))
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 40,
                          sections: sections,
                        ),
                      ),
              ),

              const SizedBox(height: 18),

              // Breakdown List
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildBalanceRow('Sleep Target 🌙', AppTimeService.formatDurationMinutes(sleepMins), const Color(0xFF475569), isDark),
                    const Divider(height: 12),
                    _buildBalanceRow('Free Flexible Time ⚡', AppTimeService.formatDurationMinutes(freeMins), const Color(0xFF00F2FE), isDark),
                    ...summaries.map((s) => Column(
                          children: [
                            const Divider(height: 12),
                            _buildBalanceRow('${s.label} (${s.progressString})', AppTimeService.formatDurationMinutes(s.plannedMinutes), s.color, isDark),
                          ],
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceRow(String label, String value, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
