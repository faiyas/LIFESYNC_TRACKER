import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifesync_ui_components.dart';
import '../../services/app_notification_scheduler.dart';
import '../../services/dynamic_option_service.dart';
import '../../services/google_sheets_backup_service.dart';
import '../../widgets/dynamic_dropdown_field.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  List<Income> _incomeList = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  int _lastDataVersion = -1;

  List<String> categories = [];
  List<String> paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadIncome();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadIncome();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadIncome() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('income', orderBy: 'date DESC, createdAt DESC');
    final dynamicCats = await DynamicOptionService.instance.getOptions(DynamicOptionService.typeIncomeSource);
    final dynamicMethods = await DynamicOptionService.instance.getOptions(DynamicOptionService.typePaymentMethod);

    if (mounted) {
      setState(() {
        _incomeList = maps.map((e) => Income.fromMap(e)).toList();
        categories = dynamicCats;
        paymentMethods = dynamicMethods;
        _isLoading = false;
      });
    }
  }

  Future<void> _addIncomeDialog() async {
    final amountController = TextEditingController();
    final sourceController = TextEditingController();
    final notesController = TextEditingController();
    String selectedCategory = categories.isNotEmpty ? categories.first : 'Salary';
    String selectedMethod = paymentMethods.isNotEmpty ? paymentMethods.first : 'UPI';
    DateTime selectedDate = DateTime.now();
    bool isTaxRelevant = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.add_circle_outline, color: AppTheme.positiveColor),
                            SizedBox(width: 8),
                            Text('Add Income Stream 📈', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Income Amount',
                        prefixText: '₹ ',
                        prefixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sourceController,
                      decoration: InputDecoration(
                        labelText: 'Income Source / Payer',
                        prefixIcon: const Icon(Icons.business_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DynamicDropdownField(
                      type: DynamicOptionService.typeIncomeSource,
                      label: 'Category',
                      prefixIcon: Icons.category_outlined,
                      initialValue: selectedCategory,
                      onChanged: (val) => setModalState(() => selectedCategory = val),
                    ),
                    const SizedBox(height: 12),
                    DynamicDropdownField(
                      type: DynamicOptionService.typePaymentMethod,
                      label: 'Payment Method',
                      prefixIcon: Icons.payment_outlined,
                      initialValue: selectedMethod,
                      onChanged: (val) => setModalState(() => selectedMethod = val),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setModalState(() => selectedDate = picked);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
                            const SizedBox(width: 10),
                            Text('Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}', style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        prefixIcon: const Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tax Relevant / Business Income', style: TextStyle(fontSize: 14)),
                      value: isTaxRelevant,
                      onChanged: (val) => setModalState(() => isTaxRelevant = val),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.positiveColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final amt = double.tryParse(amountController.text);
                          if (amt == null || amt <= 0 || sourceController.text.trim().isEmpty) return;

                          String activeProfile = 'default_profile';
                          try {
                            if (context.mounted) {
                              activeProfile = Provider.of<AppProvider>(context, listen: false).activeProfileId;
                            }
                          } catch (_) {}

                          final income = Income(
                            profileId: activeProfile,
                            amount: amt,
                            categoryId: selectedCategory,
                            source: sourceController.text.trim(),
                            paymentMethod: selectedMethod,
                            date: DateFormat('yyyy-MM-dd').format(selectedDate),
                            notes: notesController.text.isNotEmpty ? notesController.text : null,
                            isTaxRelevant: isTaxRelevant,
                          );

                          final db = await AppDatabase.instance.database;
                          await db.insert('income', income.toMap());
                          try {
                            if (context.mounted) {
                              Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                            }
                          } catch (_) {}
                          AppNotificationScheduler.instance.scheduleDailyFinancialSummary();
                          if (mounted) Navigator.pop(context);
                          _loadIncome();
                        },
                        child: const Text('Save Income', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editIncomeDialog(Income income) async {
    final amountController = TextEditingController(text: income.amount.toStringAsFixed(income.amount % 1 == 0 ? 0 : 2));
    final sourceController = TextEditingController(text: income.source);
    final notesController = TextEditingController(text: income.notes ?? '');
    String selectedMethod = income.paymentMethod;
    DateTime selectedDate = DateTime.tryParse(income.date) ?? DateTime.now();
    bool isTaxRelevant = income.isTaxRelevant;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_note_rounded, color: AppTheme.positiveColor),
                            SizedBox(width: 8),
                            Text('Edit Income Stream ✏️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sourceController,
                      decoration: InputDecoration(
                        labelText: 'Income Source / Payer',
                        prefixIcon: const Icon(Icons.business_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DynamicDropdownField(
                      type: DynamicOptionService.typePaymentMethod,
                      label: 'Payment Method',
                      prefixIcon: Icons.payment_outlined,
                      initialValue: selectedMethod,
                      onChanged: (val) => setModalState(() => selectedMethod = val),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setModalState(() => selectedDate = picked);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
                            const SizedBox(width: 10),
                            Text('Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}', style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        prefixIcon: const Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tax Relevant / Business Income', style: TextStyle(fontSize: 14)),
                      value: isTaxRelevant,
                      onChanged: (val) => setModalState(() => isTaxRelevant = val),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.positiveColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final amt = double.tryParse(amountController.text);
                          if (amt == null || amt <= 0 || sourceController.text.trim().isEmpty) return;

                          final updated = Income(
                            id: income.id,
                            profileId: income.profileId,
                            amount: amt,
                            categoryId: income.categoryId,
                            source: sourceController.text.trim(),
                            paymentMethod: selectedMethod,
                            date: DateFormat('yyyy-MM-dd').format(selectedDate),
                            notes: notesController.text.isNotEmpty ? notesController.text : null,
                            isTaxRelevant: isTaxRelevant,
                            createdAt: income.createdAt,
                          );

                          final db = await AppDatabase.instance.database;
                          await db.update('income', updated.toMap(), where: 'id = ?', whereArgs: [income.id]);
                          try {
                            if (context.mounted) {
                              Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                            }
                          } catch (_) {}
                          AppNotificationScheduler.instance.scheduleDailyFinancialSummary();
                          if (mounted) Navigator.pop(context);
                          _loadIncome();
                        },
                        child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteIncome(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('income', where: 'id = ?', whereArgs: [id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    AppNotificationScheduler.instance.scheduleDailyFinancialSummary();
    _loadIncome();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final query = _searchController.text.toLowerCase();
    final filtered = _incomeList.where((item) {
      return query.isEmpty ||
          item.source.toLowerCase().contains(query) ||
          item.paymentMethod.toLowerCase().contains(query) ||
          (item.notes != null && item.notes!.toLowerCase().contains(query));
    }).toList();

    final totalEarned = _incomeList.fold<double>(0, (sum, item) => sum + item.amount);
    final thisMonthStr = DateFormat('yyyy-MM').format(DateTime.now());
    final thisMonthIncome = _incomeList.where((e) => e.date.startsWith(thisMonthStr)).fold<double>(0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Income Streams 📈'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined, color: AppTheme.positiveColor),
            tooltip: 'Sync with Google Sheets Cloud',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing income to Google Sheets... ☁️'),
                  duration: Duration(seconds: 2),
                ),
              );
              final res = await GoogleSheetsBackupService.instance.backupNow();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Sync finished'),
                    backgroundColor: res['success'] == true ? AppTheme.positiveColor : AppTheme.negativeColor,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadIncome,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addIncomeDialog,
        backgroundColor: AppTheme.positiveColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Income', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadIncome,
        child: Column(
          children: [
            // 1. Income Summary Hero Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Income Recorded', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.positiveColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${_incomeList.length} Streams', style: const TextStyle(color: AppTheme.positiveColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppTheme.formatCurrency(totalEarned, showSign: true, isIncome: true),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      LifeSyncMetricPill(
                        label: 'This Month',
                        value: AppTheme.formatCurrency(thisMonthIncome, showSign: true, isIncome: true),
                        color: AppTheme.positiveColor,
                      ),
                      LifeSyncMetricPill(
                        label: 'Avg / Stream',
                        value: _incomeList.isNotEmpty ? AppTheme.formatCurrency(totalEarned / _incomeList.length) : '₹0',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search source, notes, payment method...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _searchController.clear()),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            const SizedBox(height: 8),

            // 3. Income Streams List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const LifeSyncEmptyState(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'No income streams found',
                          message: 'Tap "+ Add Income" below to record incoming cash flow, salary or deposits.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => _editIncomeDialog(item),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 19,
                                        backgroundColor: AppTheme.positiveColor.withAlpha(25),
                                        child: const Icon(Icons.arrow_downward_rounded, color: AppTheme.positiveColor, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              item.source,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${item.date} • ${item.paymentMethod}${item.isTaxRelevant ? ' • Taxable' : ''}',
                                              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppTheme.formatCurrency(item.amount, showSign: true, isIncome: true),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: AppTheme.positiveColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _deleteIncome(item.id),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
