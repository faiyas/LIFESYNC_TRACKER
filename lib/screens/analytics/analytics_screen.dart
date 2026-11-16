import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/app_database.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, double> _categoryTotals = {};
  double _grandTotal = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;

    final catMap = <String, double>{};
    double total = 0.0;

    // General Expenses
    try {
      final maps = await db.rawQuery('SELECT categoryId, SUM(amount) as total FROM expenses GROUP BY categoryId');
      for (var r in maps) {
        final cat = r['categoryId'] as String? ?? 'General';
        final amt = (r['total'] as num?)?.toDouble() ?? 0.0;
        catMap[cat] = (catMap[cat] ?? 0.0) + amt;
        total += amt;
      }
    } catch (_) {}

    // Trip Expenses
    try {
      final tripMaps = await db.rawQuery('SELECT category, SUM(amount) as total FROM trip_expenses GROUP BY category');
      for (var r in tripMaps) {
        final cat = 'Trip: ${r['category'] as String? ?? 'Misc'}';
        final amt = (r['total'] as num?)?.toDouble() ?? 0.0;
        catMap[cat] = (catMap[cat] ?? 0.0) + amt;
        total += amt;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _categoryTotals = catMap;
        _grandTotal = total;
        _isLoading = false;
      });
    }
  }

  final colors = [
    const Color(0xFF6366F1),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
    const Color(0xFFEF4444),
    const Color(0xFF3B82F6),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
    const Color(0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Linked Spending Analytics 📊')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categoryTotals.isEmpty
              ? const Center(child: Text('No expense or trip data available for analytics'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Text('Total Unified Expenditure (General + Trips)', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 6),
                              Text(
                                '₹${_grandTotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 200,
                                child: PieChart(
                                  PieChartData(
                                    sections: _categoryTotals.entries.map((entry) {
                                      final index = _categoryTotals.keys.toList().indexOf(entry.key);
                                      final color = colors[index % colors.length];
                                      final pct = _grandTotal > 0 ? (entry.value / _grandTotal * 100) : 0;
                                      return PieChartSectionData(
                                        color: color,
                                        value: entry.value,
                                        title: '${pct.toStringAsFixed(0)}%',
                                        radius: 50,
                                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Icon(Icons.pie_chart, color: Color(0xFF0284C7)),
                          SizedBox(width: 8),
                          Text('Category Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._categoryTotals.entries.map((e) {
                        final index = _categoryTotals.keys.toList().indexOf(e.key);
                        final color = colors[index % colors.length];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: color, radius: 10),
                            title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Text('₹${e.value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}
