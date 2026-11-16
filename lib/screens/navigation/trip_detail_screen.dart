import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../models/my_day_models.dart';
import '../../providers/app_provider.dart';
import '../../database/repositories/trip_repository.dart';
import '../../services/map_redirection_service.dart';
import '../../services/notification_service.dart';
import '../../services/dynamic_option_service.dart';
import '../../widgets/dynamic_dropdown_field.dart';

class TripDetailScreen extends StatefulWidget {
  final TripPlanModel initialTrip;

  const TripDetailScreen({super.key, required this.initialTrip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TripPlanModel _trip;

  List<TripExpense> _expenses = [];
  List<TripLocationItem> _locations = [];
  List<Map<String, dynamic>> _checklist = [];
  List<Map<String, dynamic>> _itinerary = [];
  double _totalSpent = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _trip = widget.initialTrip;
    _tabController = TabController(length: 4, vsync: this);
    _loadTripData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTripData() async {
    setState(() => _isLoading = true);
    final freshTrip = await TripRepository.getTripById(_trip.id) ?? _trip;
    final expenses = await TripRepository.getTripExpenses(_trip.id);
    final locations = await TripRepository.getTripLocations(_trip.id);
    final totalSpent = await TripRepository.getTripTotalSpent(_trip.id);

    List<Map<String, dynamic>> parsedChecklist = [];
    if (freshTrip.checklistJson != null && freshTrip.checklistJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(freshTrip.checklistJson!);
        if (decoded is List) {
          parsedChecklist = List<Map<String, dynamic>>.from(decoded);
        }
      } catch (e) {
        debugPrint('Checklist parse error: $e');
      }
    }

    List<Map<String, dynamic>> parsedItinerary = [];
    if (freshTrip.itineraryJson != null && freshTrip.itineraryJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(freshTrip.itineraryJson!);
        if (decoded is List) {
          parsedItinerary = List<Map<String, dynamic>>.from(decoded);
        }
      } catch (e) {
        debugPrint('Itinerary parse error: $e');
      }
    }

    if (mounted) {
      setState(() {
        _trip = freshTrip;
        _expenses = expenses;
        _locations = locations;
        _checklist = parsedChecklist;
        _itinerary = parsedItinerary;
        _totalSpent = totalSpent;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTripStatus(String newStatus) async {
    final updated = TripPlanModel(
      id: _trip.id,
      profileId: _trip.profileId,
      title: _trip.title,
      destination: _trip.destination,
      destinationMapUrl: _trip.destinationMapUrl,
      startDate: _trip.startDate,
      endDate: _trip.endDate,
      budget: _trip.budget,
      currency: _trip.currency,
      status: newStatus,
      coverCategory: _trip.coverCategory,
      notes: _trip.notes,
      checklistJson: _trip.checklistJson,
      itineraryJson: _trip.itineraryJson,
      createdAt: _trip.createdAt,
    );
    await TripRepository.updateTrip(updated);
    setState(() => _trip = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Trip marked as ${newStatus.toUpperCase()}')),
    );
  }

  // =================== PUSH NOTIFICATION REMINDER MODAL ===================

  void _showSetReminderModal() {
    DateTime tripStart = DateTime.tryParse(_trip.startDate) ?? DateTime.now().add(const Duration(days: 1));
    DateTime reminderDate = tripStart.isAfter(DateTime.now()) ? tripStart : DateTime.now().add(const Duration(days: 1));
    TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0);

    final msgCtrl = TextEditingController(
      text: 'Upcoming Trip: ${_trip.title} to ${_trip.destination}! Check packing and flight details.',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      const Row(
                        children: [
                          Icon(Icons.notifications_active, color: Color(0xFF0284C7)),
                          SizedBox(width: 8),
                          Text('Trip Push Reminder 🔔', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pick date & time to receive a push notification alert for this trip.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Date & Time pickers
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: reminderDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => reminderDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('dd MMM yyyy').format(reminderDate)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: reminderTime,
                            );
                            if (picked != null) {
                              setModalState(() => reminderTime = picked);
                            }
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(reminderTime.format(context)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: msgCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notification Message *',
                      prefixIcon: const Icon(Icons.message_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Schedule Push Notification Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final msg = msgCtrl.text.trim();
                        final scheduledDateTime = DateTime(
                          reminderDate.year,
                          reminderDate.month,
                          reminderDate.day,
                          reminderTime.hour,
                          reminderTime.minute,
                        );

                        await NotificationService.instance.scheduleTripNotification(
                          tripId: _trip.id,
                          tripTitle: _trip.title,
                          destination: _trip.destination,
                          scheduledDateTime: scheduledDateTime,
                          customMessage: msg.isNotEmpty ? msg : null,
                        );

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '🔔 Push notification scheduled for ${DateFormat('dd MMM yyyy, hh:mm a').format(scheduledDateTime)}!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.alarm_on),
                      label: const Text('Schedule Push Notification', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Instant Test Push Notification Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final msg = msgCtrl.text.trim();
                        final notifId = DateTime.now().millisecondsSinceEpoch % 100000;
                        await NotificationService.instance.showNotification(
                          id: notifId,
                          title: '✈️ Trip Alert: ${_trip.title}',
                          body: msg.isNotEmpty ? msg : 'Get ready for your trip to ${_trip.destination}!',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🚀 Instant test push notification sent!')),
                        );
                      },
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Send Test Push Notification Now'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  // =================== ADD EXPENSE MODAL ===================

  void _showAddExpenseModal([TripExpense? existing]) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toString() : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final locationCtrl = TextEditingController(text: existing?.location ?? '');
    String selectedCategory = existing?.category ?? 'Food';
    String selectedMethod = existing?.paymentMethod ?? 'UPI';
    DateTime selectedDate = existing != null ? DateTime.tryParse(existing.date) ?? DateTime.now() : DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      Text(
                        existing == null ? 'Add Trip Expense 💸' : 'Edit Expense',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Expense Title *',
                      hintText: 'e.g. Seafood Dinner, Beach Scooty Rental',
                      prefixIcon: const Icon(Icons.receipt_long),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹) *',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DynamicDropdownField(
                    type: DynamicOptionService.typeExpenseCategory,
                    label: 'Category',
                    prefixIcon: Icons.category,
                    initialValue: selectedCategory,
                    onChanged: (val) => setModalState(() => selectedCategory = val),
                  ),
                  const SizedBox(height: 12),
                  DynamicDropdownField(
                    type: DynamicOptionService.typePaymentMethod,
                    label: 'Payment Method',
                    prefixIcon: Icons.payment,
                    initialValue: selectedMethod,
                    onChanged: (val) => setModalState(() => selectedMethod = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationCtrl,
                    decoration: InputDecoration(
                      labelText: 'Place / Vendor (Optional)',
                      prefixIcon: const Icon(Icons.store),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text('Expense Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      prefixIcon: const Icon(Icons.notes),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        final amount = double.tryParse(amountCtrl.text.trim());
                        if (title.isEmpty || amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid title and amount')),
                          );
                          return;
                        }

                        final expense = TripExpense(
                          id: existing?.id,
                          tripId: _trip.id,
                          title: title,
                          amount: amount,
                          category: selectedCategory,
                          date: DateFormat('yyyy-MM-dd').format(selectedDate),
                          paymentMethod: selectedMethod,
                          location: locationCtrl.text.trim().isNotEmpty ? locationCtrl.text.trim() : null,
                          notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                        );

                        if (existing == null) {
                          await TripRepository.insertTripExpense(expense);
                        } else {
                          await TripRepository.updateTripExpense(expense);
                        }

                        Navigator.pop(ctx);
                        _loadTripData();
                      },
                      icon: const Icon(Icons.save),
                      label: Text(existing == null ? 'Save Expense' : 'Update Expense'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  // =================== ADD LOCATION TO STORE MODAL ===================

  void _showAddLocationModal([TripLocationItem? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final mapUrlCtrl = TextEditingController(text: existing?.mapUrl ?? '');
    final costCtrl = TextEditingController(text: existing != null && existing.estimatedCost > 0 ? existing.estimatedCost.toString() : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String selectedCategory = existing?.category ?? 'Attraction';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      Text(
                        existing == null ? 'Save Place to Visit 📍' : 'Edit Place',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Place Name *',
                      hintText: 'e.g. Chapora Fort, Curlies Beach Shack',
                      prefixIcon: const Icon(Icons.place),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DynamicDropdownField(
                    type: DynamicOptionService.typeTripCategory,
                    label: 'Category',
                    prefixIcon: Icons.category,
                    initialValue: selectedCategory,
                    onChanged: (val) => setModalState(() => selectedCategory = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Address or Area',
                      hintText: 'e.g. North Goa / Calangute Road',
                      prefixIcon: const Icon(Icons.location_city),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mapUrlCtrl,
                    decoration: InputDecoration(
                      labelText: 'Google Maps Link (Optional)',
                      hintText: 'Paste Google Maps URL or leave blank',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Estimated Entry / Activity Cost (₹)',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Notes / Timings',
                      hintText: 'e.g. Open 9 AM - 6 PM, visit at sunset',
                      prefixIcon: const Icon(Icons.notes),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a place name')),
                          );
                          return;
                        }

                        final item = TripLocationItem(
                          id: existing?.id,
                          tripId: _trip.id,
                          name: name,
                          category: selectedCategory,
                          address: addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null,
                          mapUrl: mapUrlCtrl.text.trim().isNotEmpty ? mapUrlCtrl.text.trim() : null,
                          estimatedCost: double.tryParse(costCtrl.text.trim()) ?? 0.0,
                          notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                          isVisited: existing?.isVisited ?? false,
                        );

                        if (existing == null) {
                          await TripRepository.insertTripLocation(item);
                        } else {
                          await TripRepository.updateTripLocation(item);
                        }

                        Navigator.pop(ctx);
                        _loadTripData();
                      },
                      icon: const Icon(Icons.add_location_alt),
                      label: Text(existing == null ? 'Add to Location Store' : 'Update Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  // =================== CHECKLIST & ITINERARY HANDLERS ===================

  Future<void> _toggleChecklistItem(int index) async {
    setState(() {
      _checklist[index]['isDone'] = !(_checklist[index]['isDone'] == true);
    });
    final updated = TripPlanModel(
      id: _trip.id,
      profileId: _trip.profileId,
      title: _trip.title,
      destination: _trip.destination,
      destinationMapUrl: _trip.destinationMapUrl,
      startDate: _trip.startDate,
      endDate: _trip.endDate,
      budget: _trip.budget,
      currency: _trip.currency,
      status: _trip.status,
      coverCategory: _trip.coverCategory,
      notes: _trip.notes,
      checklistJson: jsonEncode(_checklist),
      itineraryJson: _trip.itineraryJson,
      createdAt: _trip.createdAt,
    );
    await TripRepository.updateTrip(updated);
  }

  void _showAddChecklistItemModal() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Checklist Item 🎒'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Passport, Swimming Goggles, Hotel Voucher',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = textCtrl.text.trim();
              if (text.isNotEmpty) {
                final newItem = {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'text': text,
                  'isDone': false,
                };
                setState(() => _checklist.add(newItem));
                final updated = TripPlanModel(
                  id: _trip.id,
                  profileId: _trip.profileId,
                  title: _trip.title,
                  destination: _trip.destination,
                  destinationMapUrl: _trip.destinationMapUrl,
                  startDate: _trip.startDate,
                  endDate: _trip.endDate,
                  budget: _trip.budget,
                  currency: _trip.currency,
                  status: _trip.status,
                  coverCategory: _trip.coverCategory,
                  notes: _trip.notes,
                  checklistJson: jsonEncode(_checklist),
                  itineraryJson: _trip.itineraryJson,
                  createdAt: _trip.createdAt,
                );
                await TripRepository.updateTrip(updated);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddItineraryModal() {
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '10:00 AM');
    final locCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    int selectedDay = 1;

    showModalBottomSheet(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Itinerary Activity 🗓️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Day: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    DropdownButton<int>(
                      value: selectedDay,
                      items: List.generate(14, (i) => i + 1)
                          .map((d) => DropdownMenuItem(value: d, child: Text('Day $d')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedDay = v);
                      },
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: TextField(
                        controller: timeCtrl,
                        decoration: const InputDecoration(labelText: 'Time', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Activity Title *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locCtrl,
                  decoration: const InputDecoration(labelText: 'Location / Spot', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      final loc = locCtrl.text.trim();
                      final newItem = {
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'day': selectedDay,
                        'title': title,
                        'time': timeCtrl.text.trim(),
                        'location': loc,
                        'mapUrl': loc.isNotEmpty ? 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(loc)}' : null,
                        'notes': notesCtrl.text.trim(),
                        'isCompleted': false,
                      };
                      setState(() => _itinerary.add(newItem));
                      final updated = TripPlanModel(
                        id: _trip.id,
                        profileId: _trip.profileId,
                        title: _trip.title,
                        destination: _trip.destination,
                        destinationMapUrl: _trip.destinationMapUrl,
                        startDate: _trip.startDate,
                        endDate: _trip.endDate,
                        budget: _trip.budget,
                        currency: _trip.currency,
                        status: _trip.status,
                        coverCategory: _trip.coverCategory,
                        notes: _trip.notes,
                        checklistJson: _trip.checklistJson,
                        itineraryJson: jsonEncode(_itinerary),
                        createdAt: _trip.createdAt,
                      );
                      await TripRepository.updateTrip(updated);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Add Activity'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // =================== BUILD MAIN VIEW ===================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final remainingBudget = _trip.budget - _totalSpent;
    final budgetProgress = _trip.budget > 0 ? (_totalSpent / _trip.budget).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = _trip.budget > 0 && _totalSpent > _trip.budget;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _trip.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Set Trip Push Reminder',
            onPressed: _showSetReminderModal,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'planned' || val == 'ongoing' || val == 'completed' || val == 'cancelled') {
                _updateTripStatus(val);
              } else if (val == 'delete') {
                _confirmDeleteTrip();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'planned', child: Text('Status: Planned 🗓️')),
              const PopupMenuItem(value: 'ongoing', child: Text('Status: Ongoing ✈️')),
              const PopupMenuItem(value: 'completed', child: Text('Status: Completed ✅')),
              const PopupMenuItem(value: 'cancelled', child: Text('Status: Cancelled ❌')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Trip 🗑️', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Hero Trip Banner with Map Redirection Button
                _buildHeroBanner(isDark, remainingBudget, budgetProgress, isOverBudget),

                // Tab Bar
                Container(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: const Color(0xFF0284C7),
                    unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                    indicatorColor: const Color(0xFF0284C7),
                    indicatorWeight: 3,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                        text: 'Budget (${_expenses.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.pin_drop_outlined, size: 20),
                        text: 'Places Store (${_locations.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.timeline_outlined, size: 20),
                        text: 'Itinerary (${_itinerary.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.checklist_rounded, size: 20),
                        text: 'Checklist (${_checklist.length})',
                      ),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBudgetTab(isDark, remainingBudget, budgetProgress, isOverBudget),
                      _buildLocationsStoreTab(isDark),
                      _buildItineraryTab(isDark),
                      _buildChecklistTab(isDark),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    return FloatingActionButton.extended(
      backgroundColor: const Color(0xFF0284C7),
      foregroundColor: Colors.white,
      onPressed: () {
        final currentTabIndex = _tabController.index;
        if (currentTabIndex == 0) {
          _showAddExpenseModal();
        } else if (currentTabIndex == 1) {
          _showAddLocationModal();
        } else if (currentTabIndex == 2) {
          _showAddItineraryModal();
        } else {
          _showAddChecklistItemModal();
        }
      },
      icon: const Icon(Icons.add),
      label: Text(_getFabLabel()),
    );
  }

  String _getFabLabel() {
    switch (_tabController.index) {
      case 0:
        return 'Add Expense';
      case 1:
        return 'Save Place';
      case 2:
        return 'Add Activity';
      case 3:
        return 'Add Item';
      default:
        return 'Add';
    }
  }

  // =================== HERO BANNER WITH MAP REDIRECTION ===================

  Widget _buildHeroBanner(bool isDark, double remainingBudget, double budgetProgress, bool isOverBudget) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Destination & Status badge
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    _trip.destination,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(_trip.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getStatusColor(_trip.status)),
                ),
                child: Text(
                  _trip.status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(_trip.status),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Dates & Duration
          Row(
            children: [
              const Icon(Icons.date_range, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                '${_trip.startDate}  ➔  ${_trip.endDate}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Actions: Open in Maps & Set Reminder
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    MapRedirectionService.openLocationInMaps(
                      locationName: _trip.destination,
                      customMapUrl: _trip.destinationMapUrl,
                    );
                  },
                  icon: const Icon(Icons.map_rounded, color: Color(0xFF0284C7), size: 18),
                  label: const Text(
                    'Open in Maps',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0284C7),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                style: IconButton.styleFrom(backgroundColor: Colors.white24),
                icon: const Icon(Icons.notifications_active, color: Colors.white),
                tooltip: 'Set Trip Push Reminder',
                onPressed: _showSetReminderModal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ongoing':
        return Colors.greenAccent;
      case 'completed':
        return Colors.lightBlueAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.amberAccent;
    }
  }

  // =================== TAB 1: BUDGET & SPEND ===================

  Widget _buildBudgetTab(bool isDark, double remainingBudget, double budgetProgress, bool isOverBudget) {
    return RefreshIndicator(
      onRefresh: _loadTripData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Budget Summary Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatBox('Total Budget', '₹${_trip.budget.toStringAsFixed(0)}', Colors.blue),
                        Container(width: 1, height: 36, color: Colors.grey.shade300),
                        _buildStatBox('Total Spent', '₹${_totalSpent.toStringAsFixed(0)}', isOverBudget ? Colors.red : Colors.orange),
                        Container(width: 1, height: 36, color: Colors.grey.shade300),
                        _buildStatBox('Remaining', '₹${remainingBudget.toStringAsFixed(0)}', remainingBudget < 0 ? Colors.red : Colors.green),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: budgetProgress,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOverBudget
                              ? Colors.red
                              : budgetProgress > 0.8
                                  ? Colors.amber
                                  : Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(budgetProgress * 100).toStringAsFixed(0)}% Used',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isOverBudget ? Colors.red : Colors.grey.shade600,
                          ),
                        ),
                        if (isOverBudget)
                          const Text(
                            '⚠️ Over Budget!',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Expense List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Logged Expenses 📑', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(
                  '${_expenses.length} records',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_expenses.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text('No expenses logged for this trip yet.'),
                        const SizedBox(height: 4),
                        const Text('Tap "+ Add Expense" below to record spending.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _expenses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final exp = _expenses[i];
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: _getCategoryColor(exp.category).withOpacity(0.15),
                            child: Icon(_getCategoryIcon(exp.category), color: _getCategoryColor(exp.category), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  exp.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${exp.date} • ${exp.paymentMethod}${exp.location != null && exp.location!.isNotEmpty ? " • ${exp.location}" : ""}',
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
                                '₹${exp.amount.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onSelected: (val) async {
                                  if (val == 'edit') {
                                    _showAddExpenseModal(exp);
                                  } else if (val == 'delete') {
                                    await TripRepository.deleteTripExpense(exp.id);
                                    _loadTripData();
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Future<void> _optimizeWaypointRoute() async {
    if (_locations.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 saved places to optimize waypoint route.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Nearest Neighbor TSP heuristic
    final unvisited = List<TripLocationItem>.from(_locations);
    final List<TripLocationItem> optimized = [];

    var current = unvisited.removeAt(0);
    optimized.add(current);

    while (unvisited.isNotEmpty) {
      int nearestIdx = 0;
      double minDistance = double.infinity;

      for (int i = 0; i < unvisited.length; i++) {
        final cand = unvisited[i];
        double dist;
        if (current.latitude != 0 && current.longitude != 0 && cand.latitude != 0 && cand.longitude != 0) {
          final dLat = cand.latitude - current.latitude;
          final dLon = cand.longitude - current.longitude;
          dist = (dLat * dLat) + (dLon * dLon);
        } else {
          dist = (!cand.isVisited ? 0.0 : 100.0) + (i * 1.0);
        }

        if (dist < minDistance) {
          minDistance = dist;
          nearestIdx = i;
        }
      }

      current = unvisited.removeAt(nearestIdx);
      optimized.add(current);
    }

    setState(() {
      _locations = optimized;
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ Waypoint itinerary optimized for shortest travel path!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _syncItineraryToMyDay() async {
    if (_itinerary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No itinerary activities to sync. Add activities first!')),
      );
      return;
    }

    DateTime tripStartDate;
    try {
      tripStartDate = DateTime.parse(_trip.startDate);
    } catch (_) {
      tripStartDate = DateTime.now();
    }

    final db = await AppDatabase.instance.database;
    int syncedCount = 0;

    for (final item in _itinerary) {
      final dayNum = (item['day'] as num?)?.toInt() ?? 1;
      final targetDate = tripStartDate.add(Duration(days: dayNum - 1));
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      final rawTime = (item['time'] as String?) ?? '10:00 AM';
      final title = item['title'] as String? ?? 'Trip Activity';
      final location = item['location'] as String? ?? _trip.destination;

      final task = MyDayTask(
        profileId: _trip.profileId,
        title: '✈️ ${_trip.destination}: $title',
        notes: location.isNotEmpty ? 'Location: $location' : null,
        date: dateStr,
        startTime: rawTime,
        durationMinutes: 60,
        category: 'travel',
        priority: 'medium',
        schedulingType: 'fixed',
      );

      await db.insert('my_day_tasks', task.toMap());
      syncedCount++;
    }

    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗓️ Successfully synced $syncedCount itinerary items into My Day!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // =================== TAB 2: PLACES / LOCATION STORE WITH MAP REDIRECTION ===================

  Widget _buildLocationsStoreTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadTripData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Saved Spots & Places 📍', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    if (_locations.length >= 2)
                      TextButton.icon(
                        onPressed: _optimizeWaypointRoute,
                        icon: const Icon(Icons.alt_route_rounded, size: 16, color: Color(0xFF0284C7)),
                        label: const Text('Optimize Route', style: TextStyle(fontSize: 12, color: Color(0xFF0284C7))),
                      ),
                    Text(
                      '${_locations.where((l) => l.isVisited).length}/${_locations.length} Visited',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_locations.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.add_location_alt_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text('No places saved for this trip yet.'),
                        const SizedBox(height: 4),
                        const Text('Save attractions, restaurants & hotels with instant map links.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _locations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final loc = _locations[i];
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: _getCategoryColor(loc.category).withOpacity(0.15),
                                child: Icon(_getCategoryIcon(loc.category), color: _getCategoryColor(loc.category), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            loc.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              decoration: loc.isVisited ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                        ),
                                        if (loc.isVisited)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text('Visited ✅', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    if (loc.address != null && loc.address!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          loc.address!,
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ),
                                    if (loc.notes != null && loc.notes!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '💡 ${loc.notes!}',
                                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Visited Checkbox Toggle
                              InkWell(
                                onTap: () async {
                                  await TripRepository.toggleTripLocationVisited(loc.id, !loc.isVisited);
                                  _loadTripData();
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        loc.isVisited ? Icons.check_circle : Icons.radio_button_unchecked,
                                        color: loc.isVisited ? Colors.green : Colors.grey,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        loc.isVisited ? 'Mark Unvisited' : 'Mark Visited',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: loc.isVisited ? Colors.green : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                    tooltip: 'Delete Place',
                                    onPressed: () async {
                                      await TripRepository.deleteTripLocation(loc.id);
                                      _loadTripData();
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  // Map Redirection Button!
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('🗺️ Launching Maps for "${loc.name}"...')),
                                      );
                                      await MapRedirectionService.openLocationInMaps(
                                        locationName: loc.name,
                                        address: loc.address,
                                        latitude: loc.latitude != 0 ? loc.latitude : null,
                                        longitude: loc.longitude != 0 ? loc.longitude : null,
                                        customMapUrl: loc.mapUrl,
                                      );
                                    },
                                    icon: const Icon(Icons.directions, size: 16),
                                    label: const Text('Open in Maps'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // =================== TAB 3: ITINERARY ===================

  Widget _buildItineraryTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trip Timeline & Plan 🗓️', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  if (_itinerary.isNotEmpty)
                    TextButton.icon(
                      onPressed: _syncItineraryToMyDay,
                      icon: const Icon(Icons.calendar_month_outlined, size: 16, color: Colors.green),
                      label: const Text('Sync to My Day', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  TextButton.icon(
                    onPressed: _showAddItineraryModal,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Activity'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_itinerary.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.timeline, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      const Text('No day schedule added yet.'),
                      const SizedBox(height: 4),
                      const Text('Plan day-by-day sightseeing and activities.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _itinerary.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final item = _itinerary[i];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF0284C7).withOpacity(0.15),
                      child: Text(
                        'D${item['day'] ?? 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                      ),
                    ),
                    title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('⏰ ${item['time'] ?? 'All day'}  •  📍 ${item['location'] ?? 'Spot'}'),
                        if (item['notes'] != null && (item['notes'] as String).isNotEmpty)
                          Text('Notes: ${item['notes']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ),
                    trailing: (item['location'] != null && (item['location'] as String).isNotEmpty)
                        ? IconButton(
                            icon: const Icon(Icons.map_outlined, color: Color(0xFF0284C7)),
                            tooltip: 'Open in Maps',
                            onPressed: () {
                              MapRedirectionService.openLocationInMaps(
                                locationName: item['location'],
                                customMapUrl: item['mapUrl'],
                              );
                            },
                          )
                        : null,
                  ),
                );
              },
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // =================== TAB 4: CHECKLIST ===================

  Widget _buildChecklistTab(bool isDark) {
    final completedCount = _checklist.where((c) => c['isDone'] == true).length;
    final totalCount = _checklist.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Preparation & Packing 🎒', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('$completedCount of $totalCount items', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_checklist.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.checklist, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      const Text('Checklist is empty.'),
                      const SizedBox(height: 4),
                      const Text('Add packing items, bookings, and essentials.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _checklist.length,
              itemBuilder: (ctx, i) {
                final item = _checklist[i];
                final isDone = item['isDone'] == true;
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: CheckboxListTile(
                    value: isDone,
                    onChanged: (_) => _toggleChecklistItem(i),
                    title: Text(
                      item['text'] ?? '',
                      style: TextStyle(
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? Colors.grey : null,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              },
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // =================== HELPERS & DIALOGS ===================

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'transport':
        return Icons.directions_bus;
      case 'stay':
      case 'hotel':
        return Icons.hotel;
      case 'food':
      case 'dining':
        return Icons.restaurant;
      case 'activities':
      case 'attraction':
        return Icons.attractions;
      case 'viewpoint':
        return Icons.landscape;
      case 'fuel':
        return Icons.local_gas_station;
      case 'shopping':
        return Icons.shopping_bag;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'transport':
        return Colors.blue;
      case 'stay':
      case 'hotel':
        return Colors.purple;
      case 'food':
      case 'dining':
        return Colors.orange;
      case 'activities':
      case 'attraction':
        return Colors.green;
      case 'viewpoint':
        return Colors.teal;
      case 'fuel':
        return Colors.amber.shade800;
      case 'shopping':
        return Colors.pink;
      default:
        return Colors.indigo;
    }
  }

  void _confirmDeleteTrip() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trip? 🗑️'),
        content: Text('Are you sure you want to delete "${_trip.title}" and all its logged expenses and places?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await TripRepository.deleteTrip(_trip.id);
              Navigator.pop(ctx); // pop dialog
              Navigator.pop(context, true); // pop screen
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
