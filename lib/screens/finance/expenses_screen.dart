import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifesync_ui_components.dart';
import '../../services/export_service.dart';
import '../../services/app_notification_scheduler.dart';
import '../../services/dynamic_option_service.dart';
import '../../services/google_sheets_backup_service.dart';
import '../../widgets/dynamic_dropdown_field.dart';
import '../../features/payment_scanner/screens/payment_scanner_screen.dart';
import '../../features/payment_scanner/screens/auto_payment_dashboard_screen.dart';
import 'income_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String _selectedCategoryFilter = 'All';
  int _currentPage = 1;
  static const int _pageSize = 15;
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  int _lastDataVersion = -1;

  List<String> categories = [];
  List<String> paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadExpenses();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('expenses', orderBy: 'date DESC, createdAt DESC');
    final dynamicCats = await DynamicOptionService.instance.getOptions(DynamicOptionService.typeExpenseCategory);
    final dynamicMethods = await DynamicOptionService.instance.getOptions(DynamicOptionService.typePaymentMethod);

    if (mounted) {
      setState(() {
        _expenses = maps.map((e) => Expense.fromMap(e)).toList();
        categories = dynamicCats;
        paymentMethods = dynamicMethods;
        _isLoading = false;
      });
    }
  }

  void _shareExpense(Expense exp) {
    final text = 'Expense: ${exp.categoryId}\nAmount: ${AppTheme.formatCurrency(exp.amount)}\nDate: ${exp.date}\nPayment Method: ${exp.paymentMethod}${exp.location != null ? '\nMerchant: ${exp.location}' : ''}${exp.notes != null ? '\nNotes: ${exp.notes}' : ''}';
    if (exp.receiptUri != null && File(exp.receiptUri!).existsSync()) {
      ExportService.shareFile(exp.receiptUri!, text: text);
    } else {
      ExportService.shareText(text);
    }
  }

  Future<void> _addExpenseDialog() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final locationController = TextEditingController();
    String selectedCategory = categories.isNotEmpty ? categories.first : 'General';
    String selectedMethod = paymentMethods.isNotEmpty ? paymentMethods.first : 'UPI';
    DateTime selectedDate = DateTime.now();
    String? receiptPath;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickReceipt(ImageSource source) async {
              try {
                final XFile? photo = await _picker.pickImage(source: source);
                if (photo != null) {
                  setModalState(() {
                    receiptPath = photo.path;
                  });
                }
              } catch (e) {
                debugPrint('Error picking receipt: $e');
              }
            }

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
                            Icon(Icons.remove_circle_outline, color: AppTheme.negativeColor),
                            SizedBox(width: 8),
                            Text('Add Expense 💸', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        prefixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DynamicDropdownField(
                      type: DynamicOptionService.typeExpenseCategory,
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
                      controller: locationController,
                      decoration: InputDecoration(
                        labelText: 'Merchant / Location (Optional)',
                        prefixIcon: const Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickReceipt(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickReceipt(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: const Text('Gallery'),
                          ),
                        ),
                        if (receiptPath != null) ...[
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: () => setModalState(() => receiptPath = null),
                            icon: const Icon(Icons.delete_outline, color: AppTheme.negativeColor),
                            tooltip: 'Remove Photo',
                          ),
                        ],
                      ],
                    ),
                    if (receiptPath != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: File(receiptPath!).existsSync()
                            ? Image.file(File(receiptPath!), height: 90, width: double.infinity, fit: BoxFit.cover)
                            : const SizedBox.shrink(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.negativeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final amt = double.tryParse(amountController.text);
                          if (amt == null || amt <= 0) return;

                          String activeProfile = 'default_profile';
                          try {
                            if (context.mounted) {
                              activeProfile = Provider.of<AppProvider>(context, listen: false).activeProfileId;
                            }
                          } catch (_) {}

                          final expense = Expense(
                            profileId: activeProfile,
                            amount: amt,
                            categoryId: selectedCategory,
                            paymentMethod: selectedMethod,
                            date: DateFormat('yyyy-MM-dd').format(selectedDate),
                            location: locationController.text.isNotEmpty ? locationController.text : null,
                            notes: notesController.text.isNotEmpty ? notesController.text : null,
                            receiptUri: receiptPath,
                          );

                          final db = await AppDatabase.instance.database;
                          await db.insert('expenses', expense.toMap());
                          try {
                            if (context.mounted) {
                              Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                            }
                          } catch (_) {}
                          AppNotificationScheduler.instance.scheduleDailyFinancialSummary();
                          if (mounted) Navigator.pop(context);
                          _loadExpenses();
                        },
                        child: const Text('Save Expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  Future<void> _editExpenseDialog(Expense exp) async {
    final amountController = TextEditingController(text: exp.amount.toStringAsFixed(exp.amount % 1 == 0 ? 0 : 2));
    final notesController = TextEditingController(text: exp.notes ?? '');
    final locationController = TextEditingController(text: exp.location ?? '');
    String selectedCategory = exp.categoryId;
    String selectedMethod = exp.paymentMethod;
    DateTime selectedDate = DateTime.tryParse(exp.date) ?? DateTime.now();
    String? receiptPath = exp.receiptUri;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickReceipt(ImageSource source) async {
              try {
                final XFile? photo = await _picker.pickImage(source: source);
                if (photo != null) {
                  setModalState(() {
                    receiptPath = photo.path;
                  });
                }
              } catch (e) {
                debugPrint('Error picking receipt: $e');
              }
            }

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
                            Icon(Icons.edit_note_rounded, color: AppTheme.negativeColor),
                            SizedBox(width: 8),
                            Text('Edit Expense ✏️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    DynamicDropdownField(
                      type: DynamicOptionService.typeExpenseCategory,
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
                      controller: locationController,
                      decoration: InputDecoration(
                        labelText: 'Merchant / Location (Optional)',
                        prefixIcon: const Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickReceipt(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickReceipt(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: const Text('Gallery'),
                          ),
                        ),
                        if (receiptPath != null) ...[
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: () => setModalState(() => receiptPath = null),
                            icon: const Icon(Icons.delete_outline, color: AppTheme.negativeColor),
                          ),
                        ],
                      ],
                    ),
                    if (receiptPath != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: File(receiptPath!).existsSync()
                            ? Image.file(File(receiptPath!), height: 90, width: double.infinity, fit: BoxFit.cover)
                            : const SizedBox.shrink(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.negativeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final amt = double.tryParse(amountController.text);
                          if (amt == null || amt <= 0) return;

                          final updatedExpense = Expense(
                            id: exp.id,
                            profileId: exp.profileId,
                            amount: amt,
                            categoryId: selectedCategory,
                            paymentMethod: selectedMethod,
                            date: DateFormat('yyyy-MM-dd').format(selectedDate),
                            currency: exp.currency,
                            location: locationController.text.isNotEmpty ? locationController.text : null,
                            notes: notesController.text.isNotEmpty ? notesController.text : null,
                            receiptUri: receiptPath,
                            createdAt: exp.createdAt,
                          );

                          final db = await AppDatabase.instance.database;
                          await db.update('expenses', updatedExpense.toMap(), where: 'id = ?', whereArgs: [exp.id]);
                          try {
                            if (context.mounted) {
                              Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                            }
                          } catch (_) {}
                          AppNotificationScheduler.instance.scheduleDailyFinancialSummary();
                          if (mounted) Navigator.pop(context);
                          _loadExpenses();
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

  Future<void> _deleteExpense(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    AppNotificationScheduler.instance.scheduleDailyFinancialSummary();
    _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final query = _searchController.text.toLowerCase();
    final filteredExpenses = _expenses.where((exp) {
      final matchesCategory = _selectedCategoryFilter == 'All' || exp.categoryId == _selectedCategoryFilter;
      final matchesSearch = query.isEmpty ||
          exp.categoryId.toLowerCase().contains(query) ||
          exp.paymentMethod.toLowerCase().contains(query) ||
          (exp.notes != null && exp.notes!.toLowerCase().contains(query)) ||
          (exp.location != null && exp.location!.toLowerCase().contains(query));
      return matchesCategory && matchesSearch;
    }).toList();

    final totalSpent = _expenses.fold<double>(0, (sum, item) => sum + item.amount);

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final thisMonthStr = DateFormat('yyyy-MM').format(DateTime.now());
    final todaySpent = _expenses.where((e) => e.date.startsWith(todayStr)).fold<double>(0, (sum, e) => sum + e.amount);
    final thisMonthSpent = _expenses.where((e) => e.date.startsWith(thisMonthStr)).fold<double>(0, (sum, e) => sum + e.amount);

    final filterCategories = ['All', ...categories];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance & Expenses 💸'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
            tooltip: 'Automated Payments (SMS, Notifications, Screenshots)',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AutoPaymentDashboardScreen()),
              );
              _loadExpenses();
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined, color: AppTheme.primaryLight),
            tooltip: 'Sync with Google Sheets Cloud',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing expenses to Google Sheets... ☁️'),
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
            icon: const Icon(Icons.qr_code_scanner, size: 20),
            tooltip: 'Scan Payment Screenshot',
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentScannerScreen()),
              );
              if (res == true) _loadExpenses();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadExpenses,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpenseDialog,
        backgroundColor: AppTheme.negativeColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadExpenses,
        child: Column(
          children: [
            // 1. Summary Hero Card (Total Expenses, Today, Month)
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
                      const Text('Total Expenses', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.negativeColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${_expenses.length} Records', style: const TextStyle(color: AppTheme.negativeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppTheme.formatCurrency(-totalSpent, showSign: true),
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
                        label: 'Today',
                        value: AppTheme.formatCurrency(-todaySpent, showSign: true),
                        color: AppTheme.negativeColor,
                      ),
                      LifeSyncMetricPill(
                        label: 'This Month',
                        value: AppTheme.formatCurrency(-thisMonthSpent, showSign: true),
                        color: AppTheme.negativeColor,
                      ),
                      LifeSyncMetricPill(
                        label: 'Avg / Transaction',
                        value: _expenses.isNotEmpty ? AppTheme.formatCurrency(totalSpent / _expenses.length) : '₹0',
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
                  hintText: 'Search merchant, category, notes...',
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

            // 3. Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: filterCategories.map((cat) {
                  final isSelected = _selectedCategoryFilter == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppTheme.negativeColor,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategoryFilter = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 6),

            // 4. Expense List Section
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredExpenses.isEmpty
                      ? const LifeSyncEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No expenses found',
                          message: 'Tap "+ Add Expense" below or scan a payment screenshot to log your expenses.',
                        )
                      : Builder(
                          builder: (context) {
                            final totalPages = (filteredExpenses.length / _pageSize).ceil();
                            final safePage = totalPages == 0 ? 1 : _currentPage.clamp(1, totalPages);
                            final pagedExpenses = filteredExpenses.skip((safePage - 1) * _pageSize).take(_pageSize).toList();

                            return Column(
                              children: [
                                Expanded(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    itemCount: pagedExpenses.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                                    itemBuilder: (context, index) {
                                      final exp = pagedExpenses[index];
                                      final categoryIcon = _getCategoryIcon(exp.categoryId);

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
                                          borderRadius: BorderRadius.circular(14),
                                          onTap: () => _editExpenseDialog(exp),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            child: Row(
                                              children: [
                                                // Leading Icon or Thumbnail
                                                exp.receiptUri != null && File(exp.receiptUri!).existsSync()
                                                    ? ClipRRect(
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Image.file(File(exp.receiptUri!), width: 38, height: 38, fit: BoxFit.cover),
                                                      )
                                                    : CircleAvatar(
                                                        radius: 19,
                                                        backgroundColor: AppTheme.negativeColor.withAlpha(25),
                                                        child: Icon(categoryIcon, color: AppTheme.negativeColor, size: 18),
                                                      ),
                                                const SizedBox(width: 12),

                                                // Title & Subtitle
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        exp.location != null && exp.location!.isNotEmpty ? exp.location! : exp.categoryId,
                                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${exp.date} • ${exp.paymentMethod}${exp.notes != null && exp.notes!.isNotEmpty ? ' • ${exp.notes}' : ''}',
                                                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                const SizedBox(width: 8),

                                                // Amount & Compact Actions
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      AppTheme.formatCurrency(-exp.amount, showSign: true),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 14,
                                                        color: AppTheme.negativeColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        InkWell(
                                                          onTap: () => _shareExpense(exp),
                                                          borderRadius: BorderRadius.circular(4),
                                                          child: const Padding(
                                                            padding: EdgeInsets.all(3),
                                                            child: Icon(Icons.share_outlined, size: 15, color: Colors.grey),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        InkWell(
                                                          onTap: () => _deleteExpense(exp.id),
                                                          borderRadius: BorderRadius.circular(4),
                                                          child: const Padding(
                                                            padding: EdgeInsets.all(3),
                                                            child: Icon(Icons.delete_outline, size: 15, color: Colors.grey),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (totalPages > 1)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Showing ${(safePage - 1) * _pageSize + 1}-${((safePage - 1) * _pageSize + pagedExpenses.length)} of ${filteredExpenses.length}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.chevron_left, size: 20),
                                              visualDensity: VisualDensity.compact,
                                              onPressed: safePage > 1 ? () => setState(() => _currentPage--) : null,
                                            ),
                                            Text('$safePage / $totalPages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            IconButton(
                                              icon: const Icon(Icons.chevron_right, size: 20),
                                              visualDensity: VisualDensity.compact,
                                              onPressed: safePage < totalPages ? () => setState(() => _currentPage++) : null,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
      case 'travel':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'bills':
      case 'recharge':
        return Icons.receipt_long;
      case 'entertainment':
      case 'movie':
        return Icons.movie;
      case 'health':
        return Icons.medical_services;
      default:
        return Icons.category_outlined;
    }
  }
}
