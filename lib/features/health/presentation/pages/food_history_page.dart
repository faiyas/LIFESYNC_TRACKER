import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/health_models.dart';
import '../../data/repositories/health_repository.dart';
import '../../domain/services/nutrition_calculator.dart';
import '../controllers/health_controller.dart';

class FoodHistoryPage extends ConsumerStatefulWidget {
  const FoodHistoryPage({super.key});

  @override
  ConsumerState<FoodHistoryPage> createState() => _FoodHistoryPageState();
}

class _FoodHistoryPageState extends ConsumerState<FoodHistoryPage> {
  String _selectedFilter = 'This Week'; // 'Today', 'Yesterday', 'This Week', 'This Month', 'Custom Date'
  DateTimeRange? _customDateRange;
  List<FoodLog> _historyLogs = [];
  bool _isLoading = true;

  final List<String> _filters = ['Today', 'Yesterday', 'This Week', 'This Month', 'Custom Date'];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    String startStr;
    String endStr = DateFormat('yyyy-MM-dd').format(now);

    switch (_selectedFilter) {
      case 'Today':
        startStr = endStr;
        break;
      case 'Yesterday':
        final y = now.subtract(const Duration(days: 1));
        startStr = DateFormat('yyyy-MM-dd').format(y);
        endStr = startStr;
        break;
      case 'This Week':
        final w = now.subtract(const Duration(days: 6));
        startStr = DateFormat('yyyy-MM-dd').format(w);
        break;
      case 'This Month':
        final m = DateTime(now.year, now.month, 1);
        startStr = DateFormat('yyyy-MM-dd').format(m);
        break;
      case 'Custom Date':
        if (_customDateRange != null) {
          startStr = DateFormat('yyyy-MM-dd').format(_customDateRange!.start);
          endStr = DateFormat('yyyy-MM-dd').format(_customDateRange!.end);
        } else {
          startStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 7)));
        }
        break;
      default:
        startStr = endStr;
    }

    final logs = await HealthRepository.getFoodLogsByRange(startStr, endStr);

    if (mounted) {
      setState(() {
        _historyLogs = logs;
        _isLoading = false;
      });
    }
  }

  Map<String, List<FoodLog>> _groupByDate(List<FoodLog> logs) {
    final grouped = <String, List<FoodLog>>{};
    for (final log in logs) {
      grouped.putIfAbsent(log.date, () => []).add(log);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final groupedLogs = _groupByDate(_historyLogs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food & Nutrition History', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Filter Row
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final f = _filters[index];
                final isSelected = _selectedFilter == f;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: isSelected,
                    onSelected: (val) async {
                      if (f == 'Custom Date') {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _customDateRange = picked;
                            _selectedFilter = f;
                          });
                          _fetchHistory();
                        }
                      } else {
                        setState(() => _selectedFilter = f);
                        _fetchHistory();
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Main list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : groupedLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_toggle_off_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                            const SizedBox(height: 12),
                            const Text('No food entries in this period', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: groupedLogs.keys.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final dateKey = groupedLogs.keys.elementAt(index);
                          final dayLogs = groupedLogs[dateKey]!;
                          final totals = NutritionCalculator.calculateDailyNutritionTotals(dayLogs);

                          DateTime? dt = DateTime.tryParse(dateKey);
                          final formattedDate = dt != null ? DateFormat('EEEE, dd MMM yyyy').format(dt) : dateKey;

                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                            ),
                            child: ExpansionTile(
                              shape: const RoundedRectangleBorder(side: BorderSide.none),
                              collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF0284C7), size: 18),
                              ),
                              title: Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(
                                '${totals['calories']?.toStringAsFixed(0)} kcal • P: ${totals['protein']}g • C: ${totals['carbs']}g • F: ${totals['fat']}g',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                              ),
                              children: [
                                const Divider(height: 1),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(12),
                                  itemCount: dayLogs.length,
                                  separatorBuilder: (_, __) => const Divider(height: 8),
                                  itemBuilder: (context, logIdx) {
                                    final log = dayLogs[logIdx];
                                    return Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0284C7).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            log.mealType,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            log.foodName,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ),
                                        Text(
                                          '${log.quantity} ${log.servingUnit} • ${log.calories.toStringAsFixed(0)} kcal',
                                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
