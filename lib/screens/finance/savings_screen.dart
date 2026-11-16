import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  List<SavingsGoal> _goals = [];
  bool _isLoading = true;
  int _lastDataVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadGoals();
      }
    } catch (_) {}
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('savings_goals', orderBy: 'createdAt DESC');
    setState(() {
      _goals = maps.map((e) => SavingsGoal.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  Future<void> _addGoalDialog() async {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final currentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withAlpha(38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.savings_outlined, color: Colors.teal),
            ),
            const SizedBox(width: 12),
            const Text('Add Savings Goal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Goal Title (e.g. Emergency Fund)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.flag_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Target Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: currentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Current Saved (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
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
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final target = double.tryParse(targetController.text);
              final current = double.tryParse(currentController.text) ?? 0.0;
              if (titleController.text.isEmpty || target == null) return;

              final goal = SavingsGoal(
                profileId: 'default_profile',
                title: titleController.text,
                targetAmount: target,
                currentAmount: current,
              );

              final db = await AppDatabase.instance.database;
              await db.insert('savings_goals', goal.toMap());
              try {
                if (mounted) {
                  Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                }
              } catch (_) {}
              if (mounted) Navigator.pop(context);
              _loadGoals();
            },
            child: const Text('Create Goal', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGoalDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Goal'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
              ? const Center(child: Text('No savings goals added yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _goals.length,
                  itemBuilder: (context, index) {
                    final g = _goals[index];
                    final progress = (g.currentAmount / g.targetAmount).clamp(0.0, 1.0);
                    final pct = (progress * 100).toInt();

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
                                    g.title,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('$pct%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.teal,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${g.currentAmount.toStringAsFixed(0)} saved of ₹${g.targetAmount.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
