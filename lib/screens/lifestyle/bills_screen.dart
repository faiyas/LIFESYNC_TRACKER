import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/export_service.dart';
import '../../services/notification_service.dart';
import '../../services/dynamic_option_service.dart';
import '../../widgets/dynamic_dropdown_field.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  List<Bill> _bills = [];
  bool _isLoading = true;
  int _lastDataVersion = -1;
  final ImagePicker _picker = ImagePicker();

  bool _showCalendar = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final advanceOptions = {
    '1 Day Before': const Duration(days: 1),
    '2 Days Before': const Duration(days: 2),
    '3 Days Before': const Duration(days: 3),
    '1 Week Before': const Duration(days: 7),
    'On Due Date': Duration.zero,
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadBills();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadBills();
      }
    } catch (_) {}
  }

  Future<void> _loadBills() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('bills', orderBy: 'dueDate ASC');
    setState(() {
      _bills = maps.map((e) => Bill.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  List<Bill> _getBillsForDay(DateTime day) {
    final dayStr = DateFormat('yyyy-MM-dd').format(day);
    return _bills.where((b) => b.dueDate == dayStr).toList();
  }

  Future<void> _deleteBill(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    _loadBills();
  }

  Future<void> _scheduleBillReminder(Bill bill) async {
    String advanceLabel = '1 Day Before';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.alarm, color: Colors.amber),
                        ),
                        const SizedBox(width: 12),
                        const Text('Set Bill Reminder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Bill: ${bill.title} (Due: ${bill.dueDate})', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: advanceLabel,
                  decoration: InputDecoration(
                    labelText: 'Remind Me',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: advanceOptions.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                  onChanged: (v) => setModalState(() => advanceLabel = v!),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final dueDt = DateTime.parse(bill.dueDate);
                      final remindDt = dueDt.subtract(advanceOptions[advanceLabel]!);

                      final rem = Reminder(
                        profileId: bill.profileId,
                        title: 'Bill Due: ${bill.title}',
                        dateTime: remindDt.toIso8601String(),
                        linkedEntityId: bill.id,
                        linkedEntityType: 'bill',
                        notes: 'Amount: ₹${bill.amount.toStringAsFixed(2)} due on ${bill.dueDate}',
                      );

                      final db = await AppDatabase.instance.database;
                      await db.insert('reminders', rem.toMap());
                      try {
                        if (mounted) {
                          Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                        }
                      } catch (_) {}

                      await NotificationService.instance.showNotification(
                        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                        title: 'Bill Reminder: ${bill.title}',
                        body: '₹${bill.amount.toStringAsFixed(2)} is due on ${bill.dueDate}',
                      );

                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reminder set for ${DateFormat('dd MMM yyyy').format(remindDt)}')),
                        );
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addBillDialog() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    String? pickedImagePath;
    String category = 'Utilities';

    final dynamicCats = await DynamicOptionService.instance.getOptions(DynamicOptionService.typeExpenseCategory);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.receipt_long, color: Colors.indigo),
                          ),
                          const SizedBox(width: 10),
                          const Text('Add New Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Bill / Warranty Title *',
                      hintText: 'e.g. Electricity, Laptop AMC',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹) *',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  DynamicDropdownField(
                    type: DynamicOptionService.typeExpenseCategory,
                    label: 'Category',
                    prefixIcon: Icons.category,
                    initialValue: dynamicCats.contains(category) ? category : dynamicCats.firstOrNull,
                    onChanged: (val) => setModalState(() => category = val),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('Due Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}'),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes / Policy Number (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Image attachment
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final img = await _picker.pickImage(source: ImageSource.camera);
                          if (img != null) {
                            setModalState(() => pickedImagePath = img.path);
                          }
                        },
                        icon: const Icon(Icons.camera_alt, size: 16),
                        label: const Text('Camera'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final img = await _picker.pickImage(source: ImageSource.gallery);
                          if (img != null) {
                            setModalState(() => pickedImagePath = img.path);
                          }
                        },
                        icon: const Icon(Icons.photo_library, size: 16),
                        label: const Text('Gallery'),
                      ),
                      if (pickedImagePath != null) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const Text(' Attached', style: TextStyle(color: Colors.green, fontSize: 12)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final amount = double.tryParse(amountController.text.trim());

                        if (title.isEmpty || amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter valid bill title and amount.')),
                          );
                          return;
                        }

                        final bill = Bill(
                          profileId: 'default_profile',
                          title: title,
                          amount: amount,
                          dueDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                          categoryId: category,
                          fileUri: pickedImagePath,
                          notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                        );

                        final db = await AppDatabase.instance.database;
                        await db.insert('bills', bill.toMap());
                        try {
                          if (mounted) {
                            Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                          }
                        } catch (_) {}

                        if (mounted) Navigator.pop(ctx);
                        _loadBills();
                      },
                      child: const Text('Save Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Future<void> _togglePaid(Bill bill) async {
    final db = await AppDatabase.instance.database;
    final updated = Bill(
      id: bill.id,
      profileId: bill.profileId,
      title: bill.title,
      amount: bill.amount,
      dueDate: bill.dueDate,
      categoryId: bill.categoryId,
      fileUri: bill.fileUri,
      warrantyExpiry: bill.warrantyExpiry,
      isPaid: !bill.isPaid,
      notes: bill.notes,
      createdAt: bill.createdAt,
    );
    await db.update('bills', updated.toMap(), where: 'id = ?', whereArgs: [bill.id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    _loadBills();
  }

  void _shareBill(Bill bill) {
    final text = 'Bill: ${bill.title}\nAmount: ₹${bill.amount.toStringAsFixed(2)}\nDue Date: ${bill.dueDate}\nStatus: ${bill.isPaid ? 'Paid' : 'Pending'}';
    if (bill.fileUri != null && File(bill.fileUri!).existsSync()) {
      ExportService.shareFile(bill.fileUri!, text: text);
    } else {
      ExportService.shareText(text);
    }
  }

  void _showImagePreview(Bill bill) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.file(File(bill.fileUri!)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _shareBill(bill),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillCard(Bill bill) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isOverdue = !bill.isPaid && bill.dueDate.compareTo(today) < 0;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOverdue
            ? const BorderSide(color: Colors.redAccent, width: 1.5)
            : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: bill.isPaid,
              onChanged: (_) => _togglePaid(bill),
            ),
            if (bill.fileUri != null && File(bill.fileUri!).existsSync()) ...[
              GestureDetector(
                onTap: () => _showImagePreview(bill),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(bill.fileUri!), width: 40, height: 40, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bill.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      decoration: bill.isPaid ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Due: ${bill.dueDate}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? Colors.redAccent : Colors.grey,
                          fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (isOverdue)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('OVERDUE', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₹${bill.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: bill.isPaid ? Colors.grey : (isOverdue ? Colors.redAccent : Colors.orangeAccent),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _scheduleBillReminder(bill),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.notifications_active_outlined, color: Colors.amber, size: 16),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _shareBill(bill),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.share_outlined, color: Colors.indigo, size: 16),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _deleteBill(bill.id),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline, color: Colors.grey, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final unpaidBills = _bills.where((b) => !b.isPaid).toList();
    final totalDue = unpaidBills.fold<double>(0.0, (s, b) => s + b.amount);

    final displayedBills = _showCalendar && _selectedDay != null
        ? _getBillsForDay(_selectedDay!)
        : _bills;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills & Due Calendar'),
        actions: [
          IconButton(
            icon: Icon(_showCalendar ? Icons.view_list_rounded : Icons.calendar_month_rounded),
            tooltip: _showCalendar ? 'List View' : 'Calendar Heatmap',
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBillDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Summary Header
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(16),
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
                          const Text('Total Pending Bills', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            '₹${totalDue.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${unpaidBills.length} Unpaid',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),

                // Calendar Heatmap View
                if (_showCalendar) ...[
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        calendarFormat: CalendarFormat.month,
                        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                        eventLoader: (day) => _getBillsForDay(day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isEmpty) return null;
                            final bills = events.cast<Bill>();
                            final hasOverdue = bills.any((b) => !b.isPaid && b.dueDate.compareTo(today) < 0);
                            final hasPending = bills.any((b) => !b.isPaid);

                            final Color markerColor = hasOverdue
                                ? Colors.redAccent
                                : (hasPending ? Colors.amber : Colors.green);

                            return Positioned(
                              bottom: 1,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: markerColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_selectedDay != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Bills for ${DateFormat('dd MMM yyyy').format(_selectedDay!)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '${displayedBills.length} Bill${displayedBills.length == 1 ? '' : 's'}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],

                Expanded(
                  child: displayedBills.isEmpty
                      ? Center(
                          child: Text(
                            _showCalendar ? 'No bills due on selected date' : 'No bills tracked yet',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: displayedBills.length,
                          itemBuilder: (context, index) => _buildBillCard(displayedBills[index]),
                        ),
                ),
              ],
            ),
    );
  }
}
