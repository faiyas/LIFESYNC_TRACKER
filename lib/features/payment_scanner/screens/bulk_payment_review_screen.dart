import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../database/app_database.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../services/app_notification_scheduler.dart';
import '../../../services/dynamic_option_service.dart';
import '../../../widgets/dynamic_dropdown_field.dart';
import '../models/detected_payment.dart';
import '../services/payment_merchant_learning_service.dart';

class BulkPaymentItemDraft {
  bool isSelected;
  TextEditingController merchantCtrl;
  TextEditingController amountCtrl;
  TextEditingController notesCtrl;
  DateTime date;
  bool isIncome;
  String category;
  String incomeSource;
  String paymentMethod;
  String? imagePath;
  String? historicalBadge;

  BulkPaymentItemDraft({
    this.isSelected = true,
    required String merchant,
    required double amount,
    required this.date,
    required this.isIncome,
    required this.category,
    required this.incomeSource,
    this.paymentMethod = 'UPI',
    String notes = 'Imported via Statement Scan',
    this.imagePath,
    this.historicalBadge,
  })  : merchantCtrl = TextEditingController(text: merchant),
        amountCtrl = TextEditingController(text: amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2)),
        notesCtrl = TextEditingController(text: notes);

  void dispose() {
    merchantCtrl.dispose();
    amountCtrl.dispose();
    notesCtrl.dispose();
  }
}

class BulkPaymentReviewScreen extends StatefulWidget {
  final List<DetectedPayment> detectedPayments;

  const BulkPaymentReviewScreen({super.key, required this.detectedPayments});

  @override
  State<BulkPaymentReviewScreen> createState() => _BulkPaymentReviewScreenState();
}

class _BulkPaymentReviewScreenState extends State<BulkPaymentReviewScreen> {
  final List<BulkPaymentItemDraft> _drafts = [];
  bool _isSaving = false;
  List<MerchantSpendingGroup> _merchantGroups = [];

  @override
  void initState() {
    super.initState();
    _initDrafts();
  }

  Future<void> _initDrafts() async {
    _merchantGroups = PaymentMerchantLearningService.instance.calculateMerchantSummary(widget.detectedPayments);

    for (final p in widget.detectedPayments) {
      if (p.amount != null && p.amount! > 0) {
        final merchantName = p.merchant ?? (p.isIncome ? 'Income Source' : 'Unknown Merchant');
        
        final draft = BulkPaymentItemDraft(
          merchant: merchantName,
          amount: p.amount!,
          date: p.date ?? DateTime.now(),
          isIncome: p.isIncome,
          category: (p.suggestedCategory.isNotEmpty && p.suggestedCategory != 'General') ? p.suggestedCategory : 'Other',
          incomeSource: p.suggestedIncomeSource.isNotEmpty ? p.suggestedIncomeSource : 'Other',
          paymentMethod: p.paymentMethod ?? 'UPI',
          imagePath: p.imagePath,
        );

        draft.amountCtrl.addListener(() {
          if (mounted) setState(() {});
        });

        _drafts.add(draft);
      }
    }

    if (mounted) setState(() {});

    // Asynchronously lookup historical categories from database
    for (final draft in _drafts) {
      final match = await PaymentMerchantLearningService.instance.findHistoricalCategory(
        draft.merchantCtrl.text,
        isIncome: draft.isIncome,
      );
      if (match != null && mounted) {
        setState(() {
          if (!draft.isIncome && match.categoryId != null) {
            draft.category = match.categoryId!;
            draft.historicalBadge = 'Matched past visits';
          } else if (draft.isIncome && match.incomeSource != null) {
            draft.incomeSource = match.incomeSource!;
            draft.historicalBadge = 'Matched past sources';
          }
          if (match.paymentMethod != null) {
            draft.paymentMethod = match.paymentMethod!;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  void _toggleSelectAll(bool select) {
    setState(() {
      for (final d in _drafts) {
        d.isSelected = select;
      }
    });
  }

  Future<void> _saveAllConfirmed() async {
    final selected = _drafts.where((d) => d.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one transaction to import.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = await AppDatabase.instance.database;
      final timeStr = DateFormat('HH:mm').format(DateTime.now());
      String activeProfile = 'default_profile';
      try {
        if (mounted) {
          activeProfile = Provider.of<AppProvider>(context, listen: false).activeProfileId;
        }
      } catch (_) {}

      int expenseCount = 0;
      int incomeCount = 0;
      double totalExpense = 0;
      double totalIncome = 0;

      await db.transaction((txn) async {
        for (final item in selected) {
          final amt = double.tryParse(item.amountCtrl.text) ?? 0.0;
          if (amt <= 0) continue;

          final dateStr = DateFormat('yyyy-MM-dd').format(item.date);
          final merchant = item.merchantCtrl.text.trim();

          if (item.isIncome) {
            final income = Income(
              profileId: activeProfile,
              amount: amt,
              categoryId: item.incomeSource,
              source: merchant.isNotEmpty ? merchant : item.incomeSource,
              paymentMethod: item.paymentMethod,
              date: dateStr,
              notes: item.notesCtrl.text,
              isTaxRelevant: false,
            );
            await txn.insert('income', income.toMap());
            incomeCount++;
            totalIncome += amt;
          } else {
            final expense = Expense(
              profileId: activeProfile,
              amount: amt,
              categoryId: item.category,
              paymentMethod: item.paymentMethod,
              date: dateStr,
              time: timeStr,
              notes: item.notesCtrl.text,
              location: merchant.isNotEmpty ? merchant : null,
              receiptUri: item.imagePath,
              currency: 'INR',
            );
            await txn.insert('expenses', expense.toMap());
            expenseCount++;
            totalExpense += amt;
          }
        }
      });

      // Broadcast global reactive update
      try {
        if (mounted) {
          Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
        }
      } catch (_) {}

      // Update 11:00 PM financial summary notification
      AppNotificationScheduler.instance.scheduleDailyFinancialSummary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully imported $expenseCount Expenses (₹${totalExpense.toStringAsFixed(0)}) and $incomeCount Income (+₹${totalIncome.toStringAsFixed(0)})!'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error bulk saving transactions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transactions: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedDrafts = _drafts.where((d) => d.isSelected).toList();
    final totalExpense = selectedDrafts.where((d) => !d.isIncome).fold<double>(0, (s, d) => s + (double.tryParse(d.amountCtrl.text) ?? 0));
    final totalIncome = selectedDrafts.where((d) => d.isIncome).fold<double>(0, (s, d) => s + (double.tryParse(d.amountCtrl.text) ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text('Bulk Review (${_drafts.length} Found) 📋'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all_rounded),
            tooltip: 'Select All',
            onPressed: () => _toggleSelectAll(true),
          ),
          IconButton(
            icon: const Icon(Icons.deselect_rounded),
            tooltip: 'Deselect All',
            onPressed: () => _toggleSelectAll(false),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _isSaving || selectedDrafts.isEmpty ? null : _saveAllConfirmed,
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _isSaving
                  ? 'Importing...'
                  : 'Confirm & Import (${selectedDrafts.length}) Transactions',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
      body: _drafts.isEmpty
          ? const Center(child: Text('No transactions could be parsed from the statement.', style: TextStyle(color: Colors.grey)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Summary Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                            : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Selected', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${selectedDrafts.length} / ${_drafts.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.3)),
                        Column(
                          children: [
                            const Text('Expenses (Debit)', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('-₹${totalExpense.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          ],
                        ),
                        Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.3)),
                        Column(
                          children: [
                            const Text('Income (Credit)', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('+₹${totalIncome.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Shop / Merchant Breakdown Section
                if (_merchantGroups.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Text(
                        'Shop & Vendor Breakdown (Auto-Calculated)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _merchantGroups.length,
                      itemBuilder: (context, idx) {
                        final g = _merchantGroups[idx];
                        return Container(
                          width: 180,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                g.merchantName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${g.isIncome ? '+' : '-'}₹${g.totalAmount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: g.isIncome ? Colors.green : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${g.count} txns',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Itemized Review Cards
                ..._drafts.map((item) {
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: item.isSelected ? 2 : 0,
                    color: item.isSelected ? null : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: item.isSelected,
                                onChanged: (val) => setState(() => item.isSelected = val ?? false),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (item.isIncome ? Colors.green : Colors.redAccent).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.isIncome ? '🟢 Credit (+)' : '🔴 Debit (-)',
                                  style: TextStyle(
                                    color: item.isIncome ? Colors.green : Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('dd MMM yyyy').format(item.date),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ),
                              if (item.historicalBadge != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.historicalBadge!,
                                    style: const TextStyle(color: Colors.indigo, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              // Amount Field
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: item.amountCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Amount (₹)',
                                    prefixIcon: const Icon(Icons.currency_rupee, size: 16),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Merchant Field
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: item.merchantCtrl,
                                  decoration: InputDecoration(
                                    labelText: item.isIncome ? 'Payer Name' : 'Merchant / Shop',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              // Category or Source Dropdown
                              Expanded(
                                flex: 3,
                                child: !item.isIncome
                                    ? DynamicDropdownField(
                                        type: DynamicOptionService.typeExpenseCategory,
                                        label: 'Category',
                                        prefixIcon: Icons.category,
                                        isDense: true,
                                        initialValue: item.category,
                                        onChanged: (val) => setState(() => item.category = val),
                                      )
                                    : DynamicDropdownField(
                                        type: DynamicOptionService.typeIncomeSource,
                                        label: 'Source',
                                        prefixIcon: Icons.account_balance_wallet_rounded,
                                        isDense: true,
                                        initialValue: item.incomeSource,
                                        onChanged: (val) => setState(() => item.incomeSource = val),
                                      ),
                              ),
                              const SizedBox(width: 8),
                              // Payment Method Dropdown
                              Expanded(
                                flex: 2,
                                child: DynamicDropdownField(
                                  type: DynamicOptionService.typePaymentMethod,
                                  label: 'Method',
                                  prefixIcon: Icons.payment,
                                  isDense: true,
                                  initialValue: item.paymentMethod,
                                  onChanged: (val) => setState(() => item.paymentMethod = val),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
