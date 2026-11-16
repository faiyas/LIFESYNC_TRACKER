import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/export_service.dart';

class BorrowedMoneyScreen extends StatefulWidget {
  const BorrowedMoneyScreen({super.key});

  @override
  State<BorrowedMoneyScreen> createState() => _BorrowedMoneyScreenState();
}

class _BorrowedMoneyScreenState extends State<BorrowedMoneyScreen> {
  List<BorrowedMoney> _records = [];
  bool _isLoading = true;
  int _lastDataVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadRecords();
      }
    } catch (_) {}
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('borrowed_money', orderBy: 'dueDate ASC');
    setState(() {
      _records = maps.map((e) => BorrowedMoney.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  void _shareRecord(BorrowedMoney r) {
    final isBorrowed = r.type == 'borrowed';
    final text = '${isBorrowed ? 'Payable (Borrowed From)' : 'Receivable (Lent To)'}\nPerson: ${r.personName}\nAmount: ₹${r.amount.toStringAsFixed(2)}\nDue Date: ${r.dueDate}\nInterest Rate: ${r.interestRate}%\nStatus: ${r.status.toUpperCase()}';
    ExportService.shareText(text);
  }

  Future<void> _addRecordDialog() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final rateController = TextEditingController();
    final dueDateController = TextEditingController();
    String type = 'borrowed';

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
                    color: Colors.orange.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.handshake_outlined, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                const Text('Add Debt / Loan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.swap_horiz_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'borrowed', child: Text('Borrowed (Payable)')),
                      DropdownMenuItem(value: 'lent', child: Text('Lent (Receivable)')),
                    ],
                    onChanged: (v) => setModalState(() => type = v!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Person / Entity Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.currency_rupee),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Interest Rate (% p.a. optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.percent),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dueDateController,
                    decoration: InputDecoration(
                      labelText: 'Due Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
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
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final amt = double.tryParse(amountController.text);
                  if (nameController.text.isEmpty || amt == null) return;

                  final record = BorrowedMoney(
                    profileId: 'default_profile',
                    personName: nameController.text,
                    type: type,
                    amount: amt,
                    interestRate: double.tryParse(rateController.text) ?? 0.0,
                    dueDate: dueDateController.text.isNotEmpty
                        ? dueDateController.text
                        : DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10),
                  );

                  final db = await AppDatabase.instance.database;
                  await db.insert('borrowed_money', record.toMap());
                  try {
                    if (mounted) {
                      Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                    }
                  } catch (_) {}
                  if (mounted) Navigator.pop(context);
                  _loadRecords();
                },
                child: const Text('Save Record', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleStatus(BorrowedMoney record) async {
    final db = await AppDatabase.instance.database;
    final updated = BorrowedMoney(
      id: record.id,
      profileId: record.profileId,
      personName: record.personName,
      type: record.type,
      amount: record.amount,
      interestRate: record.interestRate,
      dueDate: record.dueDate,
      status: record.status == 'pending' ? 'paid' : 'pending',
      notes: record.notes,
      createdAt: record.createdAt,
    );
    await db.update('borrowed_money', updated.toMap(), where: 'id = ?', whereArgs: [record.id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    final borrowedTotal = _records.where((r) => r.type == 'borrowed' && r.status == 'pending').fold<double>(0, (s, r) => s + r.amount);
    final lentTotal = _records.where((r) => r.type == 'lent' && r.status == 'pending').fold<double>(0, (s, r) => s + r.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Borrowed & Lent Money')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRecordDialog,
        icon: const Icon(Icons.handshake_outlined),
        label: const Text('Add Record'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Borrowed (Payable)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('₹${borrowedTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent)),
                  ],
                ),
                Container(height: 30, width: 1, color: Colors.grey.withAlpha(50)),
                Column(
                  children: [
                    const Text('Lent (Receivable)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('₹${lentTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? const Center(child: Text('No borrowed or lent records'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _records.length,
                        itemBuilder: (context, index) {
                          final r = _records[index];
                          final isBorrowed = r.type == 'borrowed';
                          final isPaid = r.status == 'paid';

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isPaid,
                                    onChanged: (_) => _toggleStatus(r),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${r.personName} (${isBorrowed ? 'Borrowed' : 'Lent'})',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            decoration: isPaid ? TextDecoration.lineThrough : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Due: ${r.dueDate}${r.interestRate > 0 ? ' • ${r.interestRate}% interest' : ''}',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '₹${r.amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isPaid
                                              ? Colors.grey
                                              : (isBorrowed ? Colors.redAccent : Colors.green),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => _shareRecord(r),
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.share_outlined, color: Colors.indigo, size: 18),
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
