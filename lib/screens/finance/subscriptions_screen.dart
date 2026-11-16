import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  List<Subscription> _subs = [];
  bool _isLoading = true;
  int _lastDataVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadSubs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadSubs();
      }
    } catch (_) {}
  }

  Future<void> _loadSubs() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('subscriptions', orderBy: 'nextBillingDate ASC');
    setState(() {
      _subs = maps.map((e) => Subscription.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  List<Subscription> get _dueSubscriptions {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _subs.where((s) => !s.isPaused && s.nextBillingDate.compareTo(today) <= 0).toList();
  }

  Future<void> _logSubscriptionAsExpense(Subscription sub) async {
    final db = await AppDatabase.instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 1. Create expense
    final exp = Expense(
      profileId: sub.profileId,
      amount: sub.cost,
      categoryId: sub.category ?? 'Subscriptions',
      paymentMethod: 'Auto-Debit',
      date: today,
      notes: 'Auto-logged recurring subscription: ${sub.name}',
      isTaxRelevant: false,
    );
    await db.insert('expenses', exp.toMap());

    // 2. Advance nextBillingDate
    DateTime currentNextDate;
    try {
      currentNextDate = DateTime.parse(sub.nextBillingDate);
    } catch (_) {
      currentNextDate = DateTime.now();
    }

    final newBillingDate = sub.billingCycle == 'yearly'
        ? DateTime(currentNextDate.year + 1, currentNextDate.month, currentNextDate.day)
        : DateTime(currentNextDate.year, currentNextDate.month + 1, currentNextDate.day);

    final newBillingDateStr = DateFormat('yyyy-MM-dd').format(newBillingDate);

    final updatedSub = Subscription(
      id: sub.id,
      profileId: sub.profileId,
      name: sub.name,
      cost: sub.cost,
      billingCycle: sub.billingCycle,
      nextBillingDate: newBillingDateStr,
      category: sub.category,
      isPaused: sub.isPaused,
      notes: sub.notes,
    );

    await db.update('subscriptions', updatedSub.toMap(), where: 'id = ?', whereArgs: [sub.id]);

    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged ₹${sub.cost.toStringAsFixed(2)} for ${sub.name}. Next due: $newBillingDateStr'),
          backgroundColor: Colors.green,
        ),
      );
    }

    _loadSubs();
  }

  Future<void> _logAllDueSubscriptions() async {
    final due = _dueSubscriptions;
    if (due.isEmpty) return;

    for (final s in due) {
      await _logSubscriptionAsExpense(s);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged all ${due.length} due subscription expenses!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteSubscription(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('subscriptions', where: 'id = ?', whereArgs: [id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    _loadSubs();
  }

  Future<void> _togglePause(Subscription sub) async {
    final db = await AppDatabase.instance.database;
    final updated = Subscription(
      id: sub.id,
      profileId: sub.profileId,
      name: sub.name,
      cost: sub.cost,
      billingCycle: sub.billingCycle,
      nextBillingDate: sub.nextBillingDate,
      category: sub.category,
      isPaused: !sub.isPaused,
      notes: sub.notes,
    );
    await db.update('subscriptions', updated.toMap(), where: 'id = ?', whereArgs: [sub.id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    _loadSubs();
  }

  Future<void> _addSubscriptionDialog() async {
    final nameController = TextEditingController();
    final costController = TextEditingController();
    String cycle = 'monthly';
    String category = 'Entertainment';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.subscriptions_outlined, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                const Text('Add Subscription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Service Name (e.g. Netflix, Spotify)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.movie_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: costController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Cost (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.currency_rupee),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: cycle,
                    decoration: InputDecoration(
                      labelText: 'Billing Cycle',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.autorenew),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                    ],
                    onChanged: (v) => setModalState(() => cycle = v!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.category_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Entertainment', child: Text('Entertainment')),
                      DropdownMenuItem(value: 'Productivity', child: Text('Productivity')),
                      DropdownMenuItem(value: 'Utilities', child: Text('Utilities')),
                      DropdownMenuItem(value: 'Fitness', child: Text('Fitness')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setModalState(() => category = v!),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final cost = double.tryParse(costController.text);
                  if (nameController.text.isEmpty || cost == null) return;

                  final sub = Subscription(
                    profileId: 'default_profile',
                    name: nameController.text.trim(),
                    cost: cost,
                    billingCycle: cycle,
                    category: category,
                    nextBillingDate: DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10),
                  );

                  final db = await AppDatabase.instance.database;
                  await db.insert('subscriptions', sub.toMap());
                  try {
                    if (mounted) {
                      Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                    }
                  } catch (_) {}
                  if (mounted) Navigator.pop(context);
                  _loadSubs();
                },
                child: const Text('Save Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthlyTotal = _subs
        .where((s) => !s.isPaused)
        .fold<double>(0, (sum, s) => sum + (s.billingCycle == 'yearly' ? s.cost / 12 : s.cost));

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dueList = _dueSubscriptions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions & Recurring'),
        actions: [
          if (dueList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all_rounded, color: Colors.greenAccent),
              tooltip: 'Log all due expenses',
              onPressed: _logAllDueSubscriptions,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubscriptionDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Sub'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Est. Monthly Recurring', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(
                      '₹${monthlyTotal.toStringAsFixed(2)} / mo',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_subs.where((s) => !s.isPaused).length} Active',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                  ),
                ),
              ],
            ),
          ),

          if (dueList.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm_on_rounded, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${dueList.length} subscription${dueList.length > 1 ? 's are' : ' is'} due for billing!',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _logAllDueSubscriptions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Auto-Log All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _subs.isEmpty
                    ? const Center(child: Text('No active subscriptions'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _subs.length,
                        itemBuilder: (context, index) {
                          final s = _subs[index];
                          final isDue = !s.isPaused && s.nextBillingDate.compareTo(today) <= 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: isDue ? const BorderSide(color: Colors.amber, width: 1.5) : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: s.isPaused
                                            ? Colors.grey.withOpacity(0.2)
                                            : Colors.purple.withOpacity(0.15),
                                        child: Icon(
                                          Icons.subscriptions_outlined,
                                          color: s.isPaused ? Colors.grey : Colors.purple,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    s.name,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      decoration: s.isPaused ? TextDecoration.lineThrough : null,
                                                      color: s.isPaused ? Colors.grey : null,
                                                    ),
                                                  ),
                                                ),
                                                if (s.isPaused)
                                                  Container(
                                                    margin: const EdgeInsets.only(left: 6),
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text('Paused', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Next: ${s.nextBillingDate} • ${s.billingCycle}${s.category != null ? ' • ${s.category}' : ''}',
                                              style: TextStyle(
                                                color: isDue ? Colors.amber.shade700 : Colors.grey,
                                                fontWeight: isDue ? FontWeight.bold : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '₹${s.cost.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: s.isPaused ? Colors.grey : Colors.purpleAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 18),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              s.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                              size: 20,
                                              color: Colors.grey,
                                            ),
                                            tooltip: s.isPaused ? 'Resume' : 'Pause',
                                            onPressed: () => _togglePause(s),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                            tooltip: 'Delete',
                                            onPressed: () => _deleteSubscription(s.id),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _logSubscriptionAsExpense(s),
                                        icon: const Icon(Icons.receipt_long_rounded, size: 16),
                                        label: const Text('Log as Expense', style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDue ? Colors.amber.shade800 : Colors.purple,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
