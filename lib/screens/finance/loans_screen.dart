import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  List<Loan> _loans = [];
  bool _isLoading = true;
  int _lastDataVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadLoans();
      }
    } catch (_) {}
  }

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('loans');
    setState(() {
      _loans = maps.map((e) => Loan.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  Future<void> _addLoanDialog() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final rateController = TextEditingController();
    final emiController = TextEditingController();
    String loanType = 'borrowed';

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
                    color: Colors.indigo.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_outlined, color: Colors.indigo),
                ),
                const SizedBox(width: 12),
                const Text('Add Loan / EMI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: loanType,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.swap_horiz_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'borrowed', child: Text('Borrowed (Liability)')),
                      DropdownMenuItem(value: 'lent', child: Text('Lent (Asset)')),
                    ],
                    onChanged: (val) => setModalState(() => loanType = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Loan Title (e.g. Home Loan)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Principal Amount (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.currency_rupee),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Interest Rate (% p.a.)',
                      suffixText: '%',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.percent_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emiController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monthly EMI (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.calendar_month_outlined),
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
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final amt = double.tryParse(amountController.text);
                  final rate = double.tryParse(rateController.text) ?? 0.0;
                  final emi = double.tryParse(emiController.text) ?? 0.0;

                  if (titleController.text.isEmpty || amt == null) return;

                  final loan = Loan(
                    profileId: 'default_profile',
                    title: titleController.text,
                    type: loanType,
                    principalAmount: amt,
                    interestRate: rate,
                    tenureMonths: 12,
                    startDate: DateTime.now().toIso8601String().substring(0, 10),
                    monthlyEmi: emi,
                  );

                  final db = await AppDatabase.instance.database;
                  await db.insert('loans', loan.toMap());
                  try {
                    if (mounted) {
                      Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                    }
                  } catch (_) {}
                  if (mounted) Navigator.pop(context);
                  _loadLoans();
                },
                child: const Text('Save Loan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loans & EMIs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLoanDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Loan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loans.isEmpty
              ? const Center(child: Text('No loans or EMIs tracked'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _loans.length,
                  itemBuilder: (context, index) {
                    final loan = _loans[index];
                    final isBorrowed = loan.type == 'borrowed';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (isBorrowed ? Colors.red : Colors.green).withAlpha(38),
                          child: Icon(isBorrowed ? Icons.north_east : Icons.south_west, color: isBorrowed ? Colors.red : Colors.green),
                        ),
                        title: Text(loan.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Rate: ${loan.interestRate}% • EMI: ₹${loan.monthlyEmi.toStringAsFixed(2)}/mo'),
                        trailing: Text(
                          '₹${loan.principalAmount.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isBorrowed ? Colors.red : Colors.green),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
