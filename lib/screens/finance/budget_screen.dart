import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/dynamic_option_service.dart';
import '../../widgets/dynamic_dropdown_field.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<Budget> _budgets = [];
  Map<String, double> _categorySpent = {};
  bool _isLoading = true;
  int _lastDataVersion = -1;

  List<String> categories = [];

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadBudgets();
      }
    } catch (_) {}
  }

  Future<void> _loadBudgets() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());

    final budgetMaps = await db.query('budgets');
    final expenseMaps = await db.rawQuery(
      'SELECT categoryId, SUM(amount) as total FROM expenses WHERE date LIKE ? GROUP BY categoryId',
      ['$currentMonthStr%'],
    );
    final dynamicCats = await DynamicOptionService.instance.getOptions(DynamicOptionService.typeExpenseCategory);

    final spentMap = <String, double>{};
    for (var row in expenseMaps) {
      final cat = row['categoryId'] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      spentMap[cat] = total;
    }

    setState(() {
      _budgets = budgetMaps.map((e) => Budget.fromMap(e)).toList();
      _categorySpent = spentMap;
      categories = dynamicCats;
      _isLoading = false;
    });
  }

  Future<void> _setBudgetDialog() async {
    final limitController = TextEditingController();
    String selectedCat = categories.isNotEmpty ? categories.first : 'Food';
    final currentMonthFormatted = DateFormat('MMMM yyyy').format(DateTime.now());

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(38),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pie_chart_outline_rounded, color: Colors.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Set Monthly Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(currentMonthFormatted, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DynamicDropdownField(
                      type: DynamicOptionService.typeExpenseCategory,
                      label: 'Category',
                      prefixIcon: Icons.category,
                      initialValue: selectedCat,
                      onChanged: (val) => setModalState(() => selectedCat = val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: limitController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Monthly Limit (₹)',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.currency_rupee),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final limit = double.tryParse(limitController.text);
                    if (limit == null || limit <= 0) return;

                    final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());
                    String activeProfile = 'default_profile';
                    try {
                      if (context.mounted) {
                        activeProfile = Provider.of<AppProvider>(context, listen: false).activeProfileId;
                      }
                    } catch (_) {}

                    final db = await AppDatabase.instance.database;
                    await db.delete('budgets', where: 'categoryId = ?', whereArgs: [selectedCat]);
                    final newB = Budget(
                      profileId: activeProfile,
                      categoryId: selectedCat,
                      monthlyLimit: limit,
                      monthYear: currentMonthStr,
                    );
                    await db.insert('budgets', newB.toMap());
                    try {
                      if (context.mounted) {
                        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                      }
                    } catch (_) {}
                    if (mounted) Navigator.pop(context);
                    _loadBudgets();
                  },
                  child: const Text('Save Budget', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMonthLabel = DateFormat('MMMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Category Budgets'),
            Text(
              '$currentMonthLabel Spending',
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _setBudgetDialog,
        icon: const Icon(Icons.add_chart_rounded),
        label: const Text('Set Budget'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _budgets.isEmpty
              ? const Center(child: Text('No budgets set yet. Tap "Set Budget" to allocate.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _budgets.length,
                  itemBuilder: (context, index) {
                    final budget = _budgets[index];
                    final spent = _categorySpent[budget.categoryId] ?? 0.0;
                    final progress = (spent / budget.monthlyLimit).clamp(0.0, 1.0);
                    final isOver = spent > budget.monthlyLimit;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    budget.categoryId,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹${spent.toStringAsFixed(0)} / ₹${budget.monthlyLimit.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isOver ? Colors.redAccent : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(8),
                              color: isOver ? Colors.redAccent : Theme.of(context).colorScheme.primary,
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isOver
                                  ? 'Over budget this month by ₹${(spent - budget.monthlyLimit).toStringAsFixed(0)}'
                                  : 'Remaining this month: ₹${(budget.monthlyLimit - spent).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOver ? Colors.redAccent : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

