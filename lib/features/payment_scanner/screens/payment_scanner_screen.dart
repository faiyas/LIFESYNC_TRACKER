import 'dart:io';
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
import '../services/payment_ocr_service.dart';
import '../services/payment_parser_service.dart';
import '../services/payment_screenshot_service.dart';
import '../services/payment_duplicate_service.dart';
import '../services/payment_merchant_learning_service.dart';
import 'bulk_payment_review_screen.dart';

class PaymentScannerScreen extends StatefulWidget {
  final String? initialImagePath;

  const PaymentScannerScreen({super.key, this.initialImagePath});

  @override
  State<PaymentScannerScreen> createState() => _PaymentScannerScreenState();
}

class _PaymentScannerScreenState extends State<PaymentScannerScreen> {
  final _screenshotService = PaymentScreenshotService();
  final _ocrService = PaymentOcrService();
  final _parser = PaymentParserService();

  bool _loading = false;
  String? _imagePath;
  DetectedPayment? _detectedPayment;
  bool _isDuplicate = false;
  bool _isIncome = false; // Expense vs Income mode
  MerchantHistoricalMatch? _historicalMatch;

  // Form Controllers
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedCategory = 'Food';
  String _selectedIncomeSource = 'Salary';
  String _selectedMethod = 'UPI';
  DateTime _selectedDate = DateTime.now();

  List<String> _categories = [];
  List<String> _incomeSources = [];
  List<String> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadDynamicOptions();
    if (widget.initialImagePath != null && widget.initialImagePath!.isNotEmpty) {
      _processImage(widget.initialImagePath!);
    }
  }

  Future<void> _loadDynamicOptions() async {
    final cats = await DynamicOptionService.instance.getOptions(DynamicOptionService.typeExpenseCategory);
    final sources = await DynamicOptionService.instance.getOptions(DynamicOptionService.typeIncomeSource);
    final methods = await DynamicOptionService.instance.getOptions(DynamicOptionService.typePaymentMethod);
    if (mounted) {
      setState(() {
        _categories = cats;
        _incomeSources = sources;
        _paymentMethods = methods;
        if (!_categories.contains(_selectedCategory) && _categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
        if (!_incomeSources.contains(_selectedIncomeSource) && _incomeSources.isNotEmpty) {
          _selectedIncomeSource = _incomeSources.first;
        }
        if (!_paymentMethods.contains(_selectedMethod) && _paymentMethods.isNotEmpty) {
          _selectedMethod = _paymentMethods.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _processImage(String path) async {
    setState(() {
      _imagePath = path;
      _loading = true;
      _isDuplicate = false;
      _historicalMatch = null;
    });

    try {
      final rawText = await _ocrService.extractText(path);
      final multiItems = _parser.parseMultipleOrStatement(rawText, imagePath: path);

      // If statement with multiple transactions is detected, open Bulk Review Screen
      if (multiItems.length > 1 && mounted) {
        setState(() => _loading = false);
        final res = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => BulkPaymentReviewScreen(detectedPayments: multiItems),
          ),
        );
        if (res == true && mounted) {
          Navigator.pop(context, true);
        }
        return;
      }

      final detected = multiItems.isNotEmpty ? multiItems.first : _parser.parse(rawText, imagePath: path);
      final dynamicCats = await DynamicOptionService.instance.getOptions(DynamicOptionService.typeExpenseCategory);
      final dynamicSources = await DynamicOptionService.instance.getOptions(DynamicOptionService.typeIncomeSource);
      final dynamicMethods = await DynamicOptionService.instance.getOptions(DynamicOptionService.typePaymentMethod);

      // Query database for historical visits to this merchant/shop
      final histMatch = await PaymentMerchantLearningService.instance.findHistoricalCategory(
        detected.merchant ?? '',
        isIncome: detected.isIncome,
      );

      setState(() {
        _detectedPayment = detected;
        _isIncome = detected.isIncome;
        _historicalMatch = histMatch;

        _amountController.text = detected.amount != null
            ? (detected.amount! % 1 == 0 ? detected.amount!.toStringAsFixed(0) : detected.amount!.toStringAsFixed(2))
            : '';
        _merchantController.text = detected.merchant ?? '';
        _categories = dynamicCats;
        _incomeSources = dynamicSources;
        _paymentMethods = dynamicMethods;

        // Auto-select category, income source, and payment method
        if (histMatch != null) {
          if (!_isIncome && histMatch.categoryId != null) {
            _selectedCategory = _resolveMatchingCategory(histMatch.categoryId!, dynamicCats);
          } else {
            _selectedCategory = _resolveMatchingCategory(detected.suggestedCategory, dynamicCats);
          }

          if (_isIncome && histMatch.incomeSource != null) {
            _selectedIncomeSource = _resolveMatchingIncomeSource(histMatch.incomeSource!, dynamicSources);
          } else {
            _selectedIncomeSource = _resolveMatchingIncomeSource(detected.suggestedIncomeSource, dynamicSources);
          }

          if (histMatch.paymentMethod != null) {
            _selectedMethod = _resolveMatchingPaymentMethod(histMatch.paymentMethod, dynamicMethods);
          } else {
            _selectedMethod = _resolveMatchingPaymentMethod(detected.paymentMethod, dynamicMethods);
          }
        } else {
          _selectedCategory = _resolveMatchingCategory(detected.suggestedCategory, dynamicCats);
          _selectedIncomeSource = _resolveMatchingIncomeSource(detected.suggestedIncomeSource, dynamicSources);
          _selectedMethod = _resolveMatchingPaymentMethod(detected.paymentMethod, dynamicMethods);
        }

        _selectedDate = detected.date ?? DateTime.now();

        // Build rich contextual note
        final buffer = StringBuffer();
        if (detected.fuelDetails != null && detected.fuelDetails!.isNotEmpty) {
          buffer.write(detected.fuelDetails);
        } else if (detected.journeyRoute != null && detected.journeyRoute!.isNotEmpty) {
          buffer.write('Route: ${detected.journeyRoute}');
        } else if (detected.upiApp != null) {
          buffer.write('Paid via ${detected.upiApp}');
        } else {
          buffer.write(detected.isIncome ? 'UPI Credit / Received' : 'Receipt Scan');
        }

        if (detected.ticketNumber != null && detected.ticketNumber!.isNotEmpty) {
          buffer.write(' [Ref: ${detected.ticketNumber}]');
        } else if (detected.transactionId != null && detected.transactionId!.isNotEmpty) {
          buffer.write(' [Txn: ${detected.transactionId}]');
        }

        _notesController.text = buffer.toString();
      });

      // Perform duplicate check
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final duplicate = await PaymentDuplicateService.isDuplicate(
        transactionId: detected.transactionId ?? detected.ticketNumber,
        amount: detected.amount,
        dateStr: dateStr,
        merchant: detected.merchant,
        isIncome: detected.isIncome,
      );

      if (mounted) {
        setState(() => _isDuplicate = duplicate);
      }
    } catch (e) {
      debugPrint('Error scanning receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning receipt: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickGallery() async {
    final path = await _screenshotService.pickFromGallery();
    if (path != null) {
      await _processImage(path);
    }
  }

  Future<void> _pickMultipleGallery() async {
    final paths = await _screenshotService.pickMultipleFromGallery();
    if (paths.isEmpty) return;

    if (paths.length == 1) {
      await _processImage(paths.first);
      return;
    }

    setState(() => _loading = true);
    final List<DetectedPayment> bulkResults = [];

    try {
      for (final p in paths) {
        final text = await _ocrService.extractText(p);
        final parsedList = _parser.parseMultipleOrStatement(text, imagePath: p);
        bulkResults.addAll(parsedList);
      }

      if (bulkResults.isNotEmpty && mounted) {
        setState(() => _loading = false);
        final res = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => BulkPaymentReviewScreen(detectedPayments: bulkResults),
          ),
        );
        if (res == true && mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint('Error processing bulk images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing bulk screenshots: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickCamera() async {
    final path = await _screenshotService.captureFromCamera();
    if (path != null) {
      await _processImage(path);
    }
  }

  Future<void> _saveTransaction() async {
    final amountVal = double.tryParse(_amountController.text);
    if (amountVal == null || amountVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    final db = await AppDatabase.instance.database;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final timeStr = DateFormat('HH:mm').format(DateTime.now());
    String activeProfile = 'default_profile';
    try {
      if (mounted) {
        activeProfile = Provider.of<AppProvider>(context, listen: false).activeProfileId;
      }
    } catch (_) {}

    if (_isIncome) {
      // Save to income table
      final income = Income(
        profileId: activeProfile,
        amount: amountVal,
        categoryId: _selectedIncomeSource,
        source: _merchantController.text.isNotEmpty ? _merchantController.text : _selectedIncomeSource,
        paymentMethod: _selectedMethod,
        date: dateStr,
        notes: _notesController.text,
        isTaxRelevant: false,
      );
      await db.insert('income', income.toMap());
    } else {
      // Save to expenses table
      final expense = Expense(
        profileId: activeProfile,
        amount: amountVal,
        categoryId: _selectedCategory,
        paymentMethod: _selectedMethod,
        date: dateStr,
        time: timeStr,
        notes: _notesController.text,
        location: _merchantController.text.isNotEmpty ? _merchantController.text : null,
        receiptUri: _imagePath,
        currency: 'INR',
      );
      await db.insert('expenses', expense.toMap());
    }

    // Broadcast global reactive update
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}

    // Update 11:00 PM financial summary notification
    AppNotificationScheduler.instance.scheduleDailyFinancialSummary();

    if (mounted) {
      final typeName = _isIncome ? 'income ($_selectedIncomeSource)' : 'expense ($_selectedCategory)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Saved ₹${amountVal.toStringAsFixed(2)} as $typeName!'),
          backgroundColor: _isIncome ? Colors.teal : Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Receipt & Bill Scanner 🧾'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Selection Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Scan Physical Receipts, Tickets or UPI',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Upload single receipts or bulk share transaction history screenshots to import multiple entries at once.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _pickGallery,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Single Photo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _pickMultipleGallery,
                            icon: const Icon(Icons.collections_bookmark_outlined),
                            label: const Text('Bulk / List'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _loading ? null : _pickCamera,
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(12)),
                          child: const Icon(Icons.camera_alt_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyzing OCR text for tickets, petrol bills & statement totals...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

            // Image Preview
            if (_imagePath != null && File(_imagePath!).existsSync()) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 170,
                  width: double.infinity,
                  color: isDark ? Colors.black26 : Colors.grey.shade200,
                  child: Image.file(
                    File(_imagePath!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Duplicate Alert Banner
            if (_isDuplicate)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade800),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Possible Duplicate: A matching transaction for this amount/date or ticket reference already exists.',
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // Historical Match Badge
            if (_historicalMatch != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.indigo, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Auto-matched category "${_historicalMatch!.categoryId ?? _historicalMatch!.incomeSource}" from ${_historicalMatch!.frequency} past visit(s) to "${_historicalMatch!.matchedMerchant}".',
                        style: TextStyle(color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Detected Details Form Card
            if (_detectedPayment != null && !_loading)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Analysis Results',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (_isIncome ? Colors.teal : const Color(0xFF0284C7)).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _detectedPayment!.receiptTypeDisplayName,
                                    style: TextStyle(
                                      color: _isIncome ? Colors.teal : const Color(0xFF0284C7),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            avatar: Icon(
                              _detectedPayment!.isValidPayment ? Icons.verified : Icons.help_outline,
                              size: 14,
                              color: Colors.white,
                            ),
                            backgroundColor: _detectedPayment!.confidence > 0.6 ? Colors.green : Colors.orange,
                            label: Text(
                              '${(_detectedPayment!.confidence * 100).toStringAsFixed(0)}% Match',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Transaction Type Selector (Expense vs Income)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: false,
                              icon: Icon(Icons.arrow_upward_rounded, color: Colors.redAccent, size: 18),
                              label: Text('Expense (Debited)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              icon: Icon(Icons.arrow_downward_rounded, color: Colors.green, size: 18),
                              label: Text('Income (Credited)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                          selected: {_isIncome},
                          onSelectionChanged: (Set<bool> newSelection) {
                            setState(() {
                              _isIncome = newSelection.first;
                            });
                          },
                        ),
                      ),

                      // Amount Input
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount (₹)',
                          prefixIcon: const Icon(Icons.currency_rupee),
                          border: const OutlineInputBorder(),
                          suffixText: _isIncome ? 'Credit' : 'Debit',
                          suffixStyle: TextStyle(
                            color: _isIncome ? Colors.green : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Merchant / Vendor / Payer Input
                      TextField(
                        controller: _merchantController,
                        decoration: InputDecoration(
                          labelText: _isIncome ? 'Received From / Payer Name' : 'Merchant / Pump / Vendor / Shop',
                          prefixIcon: Icon(_isIncome ? Icons.person : Icons.store),
                          border: const OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Dynamic Category or Income Source Dropdown
                      if (!_isIncome)
                        DynamicDropdownField(
                          type: DynamicOptionService.typeExpenseCategory,
                          label: 'Expense Category (Auto-Detected)',
                          prefixIcon: Icons.category,
                          initialValue: _selectedCategory,
                          onChanged: (val) => setState(() => _selectedCategory = val),
                        )
                      else
                        DynamicDropdownField(
                          type: DynamicOptionService.typeIncomeSource,
                          label: 'Income Source (Auto-Detected)',
                          prefixIcon: Icons.account_balance_wallet_rounded,
                          initialValue: _selectedIncomeSource,
                          onChanged: (val) => setState(() => _selectedIncomeSource = val),
                        ),

                      const SizedBox(height: 12),

                      // Payment Method Dropdown
                      DynamicDropdownField(
                        type: DynamicOptionService.typePaymentMethod,
                        label: 'Payment Method',
                        prefixIcon: Icons.payment,
                        initialValue: _selectedMethod,
                        onChanged: (val) => setState(() => _selectedMethod = val),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes / Details (Auto-Filled)',
                          prefixIcon: Icon(Icons.notes),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveTransaction,
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(
                            _isIncome ? 'Confirm & Save Income' : 'Confirm & Save Expense',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: _isIncome ? Colors.teal : Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _resolveMatchingCategory(String suggested, List<String> availableCategories) {
    if (availableCategories.isEmpty) return suggested;

    for (final cat in availableCategories) {
      if (cat.trim().toLowerCase() == suggested.trim().toLowerCase()) {
        return cat;
      }
    }

    final s = suggested.toLowerCase();

    // 1. Transport & Fuel
    if (s.contains('transport') || s.contains('travel') || s.contains('transit') || s.contains('fuel') || s.contains('petrol') || s.contains('diesel') || s.contains('commute')) {
      for (final cat in availableCategories) {
        final c = cat.toLowerCase();
        if (c.contains('travel') ||
            c.contains('transport') ||
            c.contains('transit') ||
            c.contains('fuel') ||
            c.contains('petrol') ||
            c.contains('vehicle') ||
            c.contains('commute') ||
            c.contains('car') ||
            c.contains('bike')) {
          return cat;
        }
      }
    }

    // 2. Food & Dining & Groceries
    if (s.contains('food') || s.contains('dining') || s.contains('restaurant') || s.contains('eat') || s.contains('snack') || s.contains('cafe')) {
      for (final cat in availableCategories) {
        final c = cat.toLowerCase();
        if (c.contains('food') ||
            c.contains('dining') ||
            c.contains('restaurant') ||
            c.contains('cafe') ||
            c.contains('eat') ||
            c.contains('lunch') ||
            c.contains('dinner') ||
            c.contains('snacks') ||
            c.contains('meals')) {
          return cat;
        }
      }
    }

    // 3. Shopping & Retail
    if (s.contains('shop') || s.contains('retail') || s.contains('cloth') || s.contains('grocer')) {
      for (final cat in availableCategories) {
        final c = cat.toLowerCase();
        if (c.contains('shop') ||
            c.contains('retail') ||
            c.contains('grocer') ||
            c.contains('cloth') ||
            c.contains('dress') ||
            c.contains('purchase') ||
            c.contains('market') ||
            c.contains('supermarket')) {
          return cat;
        }
      }
    }

    // 4. Bills & Utilities
    if (s.contains('bill') || s.contains('utilit') || s.contains('recharge') || s.contains('electric') || s.contains('water') || s.contains('gas')) {
      for (final cat in availableCategories) {
        final c = cat.toLowerCase();
        if (c.contains('bill') ||
            c.contains('utilit') ||
            c.contains('recharge') ||
            c.contains('electric') ||
            c.contains('broadband') ||
            c.contains('mobile') ||
            c.contains('rent') ||
            c.contains('maintenance')) {
          return cat;
        }
      }
    }

    // 5. Health & Medical
    if (s.contains('health') || s.contains('med') || s.contains('doctor') || s.contains('pharma') || s.contains('hospital')) {
      for (final cat in availableCategories) {
        final c = cat.toLowerCase();
        if (c.contains('health') ||
            c.contains('med') ||
            c.contains('doctor') ||
            c.contains('pharma') ||
            c.contains('hospital') ||
            c.contains('fitness') ||
            c.contains('care')) {
          return cat;
        }
      }
    }

    // 6. Entertainment
    if (s.contains('entertain') || s.contains('movie') || s.contains('game') || s.contains('stream') || s.contains('music')) {
      for (final cat in availableCategories) {
        final c = cat.toLowerCase();
        if (c.contains('entertain') || c.contains('movie') || c.contains('game') || c.contains('fun') || c.contains('leisure') || c.contains('ott')) {
          return cat;
        }
      }
    }

    // 7. Education
    if (s.contains('educat') || s.contains('school') || s.contains('college') || s.contains('course') || s.contains('book')) {
      for (final cat in availableCategories) {
        final c = cat.toLowerCase();
        if (c.contains('educat') || c.contains('study') || c.contains('learn')) {
          return cat;
        }
      }
    }

    // 8. Personal Care
    if (s.contains('personal') || s.contains('salon') || s.contains('spa') || s.contains('beauty') || s.contains('groom')) {
      for (final cat in availableCategories) {
        final c = cat.toLowerCase();
        if (c.contains('personal') || c.contains('care') || c.contains('beauty') || c.contains('salon')) {
          return cat;
        }
      }
    }

    // Default fallback: Always return 'Other' or 'Others' when no specific match is found
    for (final cat in availableCategories) {
      final c = cat.toLowerCase().trim();
      if (c == 'other' || c == 'others' || c.startsWith('other')) {
        return cat;
      }
    }

    return availableCategories.isNotEmpty ? availableCategories.first : 'Other';
  }

  String _resolveMatchingIncomeSource(String suggested, List<String> availableSources) {
    if (availableSources.isEmpty) return suggested;
    for (final src in availableSources) {
      if (src.trim().toLowerCase() == suggested.trim().toLowerCase()) {
        return src;
      }
    }

    final s = suggested.toLowerCase();
    if (s.contains('salary') || s.contains('wage') || s.contains('pay')) {
      for (final src in availableSources) {
        if (src.toLowerCase().contains('salary') || src.toLowerCase().contains('wage') || src.toLowerCase().contains('job')) return src;
      }
    }

    if (s.contains('free') || s.contains('client') || s.contains('project')) {
      for (final src in availableSources) {
        if (src.toLowerCase().contains('free') || src.toLowerCase().contains('client') || src.toLowerCase().contains('contract')) return src;
      }
    }

    if (s.contains('business') || s.contains('sale') || s.contains('shop')) {
      for (final src in availableSources) {
        if (src.toLowerCase().contains('business') || src.toLowerCase().contains('sale') || src.toLowerCase().contains('store')) return src;
      }
    }

    if (s.contains('invest') || s.contains('dividend') || s.contains('stock') || s.contains('interest')) {
      for (final src in availableSources) {
        if (src.toLowerCase().contains('invest') || src.toLowerCase().contains('dividend') || src.toLowerCase().contains('interest')) return src;
      }
    }

    if (s.contains('bonus') || s.contains('reward') || s.contains('cashback') || s.contains('gift')) {
      for (final src in availableSources) {
        if (src.toLowerCase().contains('bonus') || src.toLowerCase().contains('reward') || src.toLowerCase().contains('cashback') || src.toLowerCase().contains('gift')) return src;
      }
    }

    if (s.contains('refund')) {
      for (final src in availableSources) {
        if (src.toLowerCase().contains('refund') || src.toLowerCase().contains('return')) return src;
      }
    }

    // Default fallback: Always return 'Other' for unrecognized income sources
    for (final src in availableSources) {
      final sLower = src.toLowerCase().trim();
      if (sLower == 'other' || sLower == 'others' || sLower.startsWith('other')) {
        return src;
      }
    }

    return availableSources.isNotEmpty ? availableSources.first : 'Other';
  }

  String _resolveMatchingPaymentMethod(String? suggested, List<String> availableMethods) {
    if (availableMethods.isEmpty) return suggested ?? 'UPI';
    if (suggested == null) return availableMethods.first;

    for (final method in availableMethods) {
      if (method.trim().toLowerCase() == suggested.trim().toLowerCase()) {
        return method;
      }
    }

    final s = suggested.toLowerCase();
    if (s.contains('card')) {
      for (final m in availableMethods) {
        if (m.toLowerCase().contains('card')) return m;
      }
    }
    if (s.contains('upi') || s.contains('gpay') || s.contains('phonepe') || s.contains('paytm')) {
      for (final m in availableMethods) {
        if (m.toLowerCase().contains('upi')) return m;
      }
    }
    if (s.contains('cash')) {
      for (final m in availableMethods) {
        if (m.toLowerCase().contains('cash')) return m;
      }
    }

    return availableMethods.first;
  }
}
