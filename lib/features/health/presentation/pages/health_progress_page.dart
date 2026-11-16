import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/models/health_models.dart';
import '../../data/repositories/health_repository.dart';
import '../controllers/health_controller.dart';

class HealthProgressPage extends ConsumerStatefulWidget {
  const HealthProgressPage({super.key});

  @override
  ConsumerState<HealthProgressPage> createState() => _HealthProgressPageState();
}

class _HealthProgressPageState extends ConsumerState<HealthProgressPage> {
  String _selectedMetric = 'Calories'; // 'Calories', 'Steps', 'Water', 'Weight'
  bool _isLoading = true;

  List<String> _last7Days = [];
  Map<String, double> _dailyCalories = {};
  Map<String, int> _dailySteps = {};
  Map<String, int> _dailyWater = {};
  Map<String, double> _dailyWeight = {};
  Map<String, double> _dailyProtein = {};

  double _avgCalories = 0.0;
  double _avgSteps = 0.0;
  double _avgWaterL = 0.0;
  double _avgProteinG = 0.0;

  @override
  void initState() {
    super.initState();
    _load7DaysAnalytics();
  }

  Future<void> _load7DaysAnalytics() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final days = <String>[];
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      days.add(DateFormat('yyyy-MM-dd').format(d));
    }

    final startDate = days.first;
    final endDate = days.last;

    final foodLogs = await HealthRepository.getFoodLogsByRange(startDate, endDate);
    final stepLogs = await HealthRepository.getStepLogsByRange(startDate, endDate);
    final waterAggregates = await HealthRepository.getWaterAggregatesByRange(startDate, endDate);
    final weightLogs = await HealthRepository.getAllWeightLogs();

    final calMap = <String, double>{};
    final protMap = <String, double>{};
    for (final day in days) {
      calMap[day] = 0.0;
      protMap[day] = 0.0;
    }
    for (final log in foodLogs) {
      if (calMap.containsKey(log.date)) {
        calMap[log.date] = (calMap[log.date] ?? 0.0) + log.calories;
        protMap[log.date] = (protMap[log.date] ?? 0.0) + log.protein;
      }
    }

    final stepMap = <String, int>{};
    for (final day in days) {
      stepMap[day] = 0;
    }
    for (final s in stepLogs) {
      if (stepMap.containsKey(s.date)) {
        stepMap[s.date] = s.steps;
      }
    }

    final waterMap = <String, int>{};
    for (final day in days) {
      waterMap[day] = 0;
    }
    for (final w in waterAggregates) {
      final d = w['date'] as String?;
      final ml = (w['totalMl'] as num?)?.toInt() ?? 0;
      if (d != null && waterMap.containsKey(d)) {
        waterMap[d] = ml;
      }
    }

    final weightMap = <String, double>{};
    for (final w in weightLogs) {
      if (days.contains(w.date)) {
        weightMap[w.date] = w.weightKg;
      }
    }

    final calSum = calMap.values.fold<double>(0.0, (p, e) => p + e);
    final stepSum = stepMap.values.fold<int>(0, (p, e) => p + e);
    final waterSum = waterMap.values.fold<int>(0, (p, e) => p + e);
    final protSum = protMap.values.fold<double>(0.0, (p, e) => p + e);

    if (mounted) {
      setState(() {
        _last7Days = days;
        _dailyCalories = calMap;
        _dailySteps = stepMap;
        _dailyWater = waterMap;
        _dailyWeight = weightMap;
        _dailyProtein = protMap;
        _avgCalories = calSum / 7.0;
        _avgSteps = stepSum / 7.0;
        _avgWaterL = (waterSum / 7.0) / 1000.0;
        _avgProteinG = protSum / 7.0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthState = ref.watch(healthControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Progress & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load7DaysAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 4 Average Summary Cards
                const Text('7-Day Daily Averages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildAvgCard(
                        label: 'Average Calories',
                        value: '${_avgCalories.toStringAsFixed(0)} kcal',
                        icon: Icons.local_fire_department_rounded,
                        color: const Color(0xFFF97316),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildAvgCard(
                        label: 'Average Steps',
                        value: '${_avgSteps.toStringAsFixed(0)} / day',
                        icon: Icons.directions_walk_rounded,
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildAvgCard(
                        label: 'Average Water',
                        value: '${_avgWaterL.toStringAsFixed(1)} L / day',
                        icon: Icons.water_drop_rounded,
                        color: const Color(0xFF0284C7),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildAvgCard(
                        label: 'Average Protein',
                        value: '${_avgProteinG.toStringAsFixed(0)} g / day',
                        icon: Icons.fitness_center_rounded,
                        color: const Color(0xFFEF4444),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Metric Toggle Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Weekly Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Calories', 'Steps', 'Water', 'Weight'].map((m) {
                          final isSelected = _selectedMetric == m;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ChoiceChip(
                              label: Text(m, style: const TextStyle(fontSize: 11)),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) setState(() => _selectedMetric = m);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Chart Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last 7 Days - $_selectedMetric',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 220,
                        child: _buildChart(isDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildChart(bool isDark) {
    switch (_selectedMetric) {
      case 'Steps':
        return BarChart(
          BarChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: _buildTitlesData(),
            borderData: FlBorderData(show: false),
            barGroups: _last7Days.asMap().entries.map((e) {
              final val = (_dailySteps[e.value] ?? 0).toDouble();
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: val,
                    color: const Color(0xFF10B981),
                    width: 16,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      case 'Water':
        return BarChart(
          BarChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: _buildTitlesData(),
            borderData: FlBorderData(show: false),
            barGroups: _last7Days.asMap().entries.map((e) {
              final val = ((_dailyWater[e.value] ?? 0) / 1000.0);
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: val,
                    color: const Color(0xFF0284C7),
                    width: 16,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      case 'Weight':
        final spots = <FlSpot>[];
        for (int i = 0; i < _last7Days.length; i++) {
          final w = _dailyWeight[_last7Days[i]];
          if (w != null) spots.add(FlSpot(i.toDouble(), w));
        }

        if (spots.isEmpty) {
          return const Center(child: Text('No weight logs in this period', style: TextStyle(color: Colors.grey)));
        }

        return LineChart(
          LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: _buildTitlesData(),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: const Color(0xFF8B5CF6),
                barWidth: 3,
                belowBarData: BarAreaData(show: true, color: const Color(0xFF8B5CF6).withOpacity(0.15)),
              ),
            ],
          ),
        );
      case 'Calories':
      default:
        return BarChart(
          BarChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: _buildTitlesData(),
            borderData: FlBorderData(show: false),
            barGroups: _last7Days.asMap().entries.map((e) {
              final val = _dailyCalories[e.value] ?? 0.0;
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: val,
                    color: const Color(0xFFF97316),
                    width: 16,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              );
            }).toList(),
          ),
        );
    }
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx >= 0 && idx < _last7Days.length) {
              final dt = DateTime.tryParse(_last7Days[idx]);
              if (dt != null) {
                return Text(DateFormat('E').format(dt), style: const TextStyle(fontSize: 11, color: Colors.grey));
              }
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildAvgCard({
    required String label,
    required String value,
    required IconData icon,
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
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
