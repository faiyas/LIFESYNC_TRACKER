import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/models/health_models.dart';
import '../../data/repositories/health_repository.dart';
import '../../domain/services/weight_progress_calculator.dart';
import '../controllers/health_controller.dart';

class WeightTrackerPage extends ConsumerStatefulWidget {
  const WeightTrackerPage({super.key});

  @override
  ConsumerState<WeightTrackerPage> createState() => _WeightTrackerPageState();
}

class _WeightTrackerPageState extends ConsumerState<WeightTrackerPage> {
  List<WeightLog> _allWeightLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeightLogs();
  }

  Future<void> _loadWeightLogs() async {
    setState(() => _isLoading = true);
    final logs = await HealthRepository.getAllWeightLogs();
    if (mounted) {
      setState(() {
        _allWeightLogs = logs;
        _isLoading = false;
      });
    }
  }

  void _showAddWeightDialog() {
    final healthState = ref.read(healthControllerProvider);
    final currentWeight = _allWeightLogs.isNotEmpty ? _allWeightLogs.last.weightKg : healthState.profile.weightKg;
    final weightCtrl = TextEditingController(text: currentWeight.toStringAsFixed(1));
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Today\'s Weight ⚖️'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                hintText: 'e.g. 72.5',
                suffixText: 'kg',
                prefixIcon: Icon(Icons.monitor_weight_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. Morning before breakfast',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final w = double.tryParse(weightCtrl.text.trim());
              if (w != null && w > 0) {
                Navigator.pop(ctx);
                await ref.read(healthControllerProvider.notifier).logWeight(w, notes: notesCtrl.text.trim());
                await _loadWeightLogs();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthState = ref.watch(healthControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final summary = WeightProgressCalculator.calculate(_allWeightLogs, healthState.profile.weightKg);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Log Weight',
            onPressed: _showAddWeightDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Metric stats summary
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricBox(
                        title: 'Current',
                        value: '${summary.currentWeight} kg',
                        subtitle: 'Latest entry',
                        color: const Color(0xFF0284C7),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricBox(
                        title: 'Starting',
                        value: '${summary.startingWeight} kg',
                        subtitle: 'First recorded',
                        color: const Color(0xFF8B5CF6),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricBox(
                        title: 'Weight Change',
                        value: '${summary.weightChange >= 0 ? "+" : ""}${summary.weightChange} kg',
                        subtitle: summary.weightChange < 0 ? 'Down from start' : 'Up from start',
                        color: summary.weightChange <= 0 ? const Color(0xFF10B981) : const Color(0xFFF97316),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricBox(
                        title: '7-Day Average',
                        value: '${summary.weeklyAverage} kg',
                        subtitle: 'Smoothed trend',
                        color: const Color(0xFF06B6D4),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Weight Trend Chart
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.show_chart_rounded, color: Color(0xFF0284C7), size: 20),
                          SizedBox(width: 8),
                          Text('Weight Trend Graph', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_allWeightLogs.length < 2)
                        Container(
                          height: 160,
                          alignment: Alignment.center,
                          child: const Text('Log at least 2 entries to view weight trend chart', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        )
                      else
                        SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(show: true, drawVerticalLine: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 24,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      if (idx >= 0 && idx < _allWeightLogs.length) {
                                        final d = DateTime.tryParse(_allWeightLogs[idx].date);
                                        if (d != null) {
                                          return Text(DateFormat('dd MMM').format(d), style: const TextStyle(fontSize: 10, color: Colors.grey));
                                        }
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _allWeightLogs.asMap().entries.map((e) {
                                    return FlSpot(e.key.toDouble(), e.value.weightKg);
                                  }).toList(),
                                  isCurved: true,
                                  color: const Color(0xFF0284C7),
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: const Color(0xFF0284C7).withOpacity(0.15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _showAddWeightDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Log Today\'s Weight', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // History list
                const Text('Logged History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_allWeightLogs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: const Text('Start tracking your weight today!', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _allWeightLogs.reversed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final log = _allWeightLogs.reversed.toList()[index];
                      DateTime? dt = DateTime.tryParse(log.date);
                      final formattedDate = dt != null ? DateFormat('dd MMM yyyy').format(dt) : log.date;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0284C7)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  if (log.notes != null && log.notes!.isNotEmpty)
                                    Text(log.notes!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Text(
                              '${log.weightKg.toStringAsFixed(1)} kg',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0284C7)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }

  Widget _buildMetricBox({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
