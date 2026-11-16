import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../database/repositories/trip_repository.dart';
import '../../services/map_redirection_service.dart';
import '../../services/notification_service.dart';
import 'trip_detail_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _quickSearchController = TextEditingController();

  // Trips State
  List<TripPlanModel> _trips = [];
  String _tripFilter = 'all'; // all, ongoing, planned, completed
  bool _isLoading = true;

  // Location Store State
  List<TripLocationItem> _allPlaces = [];

  // Route Launcher State
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  String _travelMode = 'driving'; // driving, transit, walking

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quickSearchController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final trips = await TripRepository.getAllTrips();
    final places = await TripRepository.getAllPlaces();

    if (mounted) {
      setState(() {
        _trips = trips;
        _allPlaces = places;
        _isLoading = false;
      });
    }
  }

  // =================== QUICK SEARCH & REDIRECTION ===================

  Future<void> _handleQuickMapSearch() async {
    final query = _quickSearchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location name, address, or map URL')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🗺️ Launching Maps for "$query"...'), duration: const Duration(seconds: 2)),
    );

    if (query.startsWith('http') || query.startsWith('geo:')) {
      await MapRedirectionService.openMapUrl(query);
    } else {
      await MapRedirectionService.openLocationInMaps(locationName: query);
    }
  }

  Future<void> _handleQuickGetDirections() async {
    final query = _quickSearchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a destination for directions')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🚗 Opening directions to "$query"...'), duration: const Duration(seconds: 2)),
    );

    await MapRedirectionService.openDirectionsToDestination(destination: query);
  }

  // =================== DELETE ACTIONS ===================

  void _confirmDeleteTrip(TripPlanModel trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trip? 🗑️'),
        content: Text('Are you sure you want to delete "${trip.title}" (${trip.destination})? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await TripRepository.deleteTrip(trip.id);
              if (mounted) {
                _loadAllData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Trip "${trip.title}" deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlace(TripLocationItem place) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Saved Location? 🗑️'),
        content: Text('Are you sure you want to remove "${place.name}" from your Location Store?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await TripRepository.deleteTripLocation(place.id);
              if (mounted) {
                _loadAllData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Location "${place.name}" removed')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAllDemoPlaces() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Saved Places? 🗑️'),
        content: const Text('Are you sure you want to delete all saved locations from the location store?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              for (var place in _allPlaces) {
                await TripRepository.deleteTripLocation(place.id);
              }
              if (mounted) {
                _loadAllData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All saved locations cleared')),
                );
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  // =================== QUICK PUSH REMINDER MODAL ===================

  void _showTripReminderModal(TripPlanModel trip) {
    DateTime tripStart = DateTime.tryParse(trip.startDate) ?? DateTime.now().add(const Duration(days: 1));
    DateTime reminderDate = tripStart.isAfter(DateTime.now()) ? tripStart : DateTime.now().add(const Duration(days: 1));
    TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0);

    final msgCtrl = TextEditingController(
      text: 'Upcoming Trip: ${trip.title} to ${trip.destination}! Check packing and flight details.',
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
                  const SizedBox(height: 8),
                  Text('Trip: ${trip.title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 14),

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
                  const SizedBox(height: 12),

                  TextField(
                    controller: msgCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Reminder Message',
                      prefixIcon: const Icon(Icons.message_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final scheduledDateTime = DateTime(
                          reminderDate.year,
                          reminderDate.month,
                          reminderDate.day,
                          reminderTime.hour,
                          reminderTime.minute,
                        );

                        await NotificationService.instance.scheduleTripNotification(
                          tripId: trip.id,
                          tripTitle: trip.title,
                          destination: trip.destination,
                          scheduledDateTime: scheduledDateTime,
                          customMessage: msgCtrl.text.trim().isNotEmpty ? msgCtrl.text.trim() : null,
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '⏰ Push notification scheduled for ${DateFormat('dd MMM yyyy').format(scheduledDateTime)} at ${reminderTime.format(context)}',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.alarm_add),
                      label: const Text('Schedule Push Notification'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await NotificationService.instance.showNotification(
                          id: DateTime.now().millisecondsSinceEpoch % 100000,
                          title: '✈️ Trip Alert: ${trip.title}',
                          body: msgCtrl.text.trim().isNotEmpty
                              ? msgCtrl.text.trim()
                              : 'Upcoming trip to ${trip.destination}!',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('🚀 Instant test push notification sent!')),
                          );
                        }
                      },
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Send Test Push Notification Now'),
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

  // =================== CREATE TRIP MODAL ===================

  void _showCreateTripModal() {
    final titleCtrl = TextEditingController();
    final destCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    final mapUrlCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    DateTime startDate = DateTime.now().add(const Duration(days: 7));
    DateTime endDate = DateTime.now().add(const Duration(days: 12));
    String selectedCategory = 'beach';
    bool scheduleReminder = true;
    TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0);

    final categories = [
      {'key': 'beach', 'label': 'Beach 🏖️'},
      {'key': 'mountains', 'label': 'Mountains ⛰️'},
      {'key': 'city', 'label': 'City Tour 🏙️'},
      {'key': 'roadtrip', 'label': 'Road Trip 🚗'},
      {'key': 'heritage', 'label': 'Heritage 🏛️'},
      {'key': 'general', 'label': 'Vacation ✈️'},
    ];

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
                          Icon(Icons.flight_takeoff, color: Color(0xFF0284C7)),
                          SizedBox(width: 8),
                          Text('Plan New Vacation Trip ✈️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Trip Name *',
                      hintText: 'e.g. Manali Snow Adventure',
                      prefixIcon: const Icon(Icons.title),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: destCtrl,
                    decoration: InputDecoration(
                      labelText: 'Destination / City *',
                      hintText: 'e.g. Manali, Himachal Pradesh',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: mapUrlCtrl,
                    decoration: InputDecoration(
                      labelText: 'Google Maps Link (Optional)',
                      hintText: 'Paste Google Maps share link or location URL',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Selector
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Trip Theme / Category',
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c['key'], child: Text(c['label']!)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedCategory = v!),
                  ),
                  const SizedBox(height: 12),

                  // Date Pickers
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() {
                                startDate = picked;
                                if (endDate.isBefore(startDate)) {
                                  endDate = startDate.add(const Duration(days: 3));
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text('Start: ${DateFormat('dd MMM yyyy').format(startDate)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => endDate = picked);
                            }
                          },
                          icon: const Icon(Icons.event, size: 16),
                          label: Text('End: ${DateFormat('dd MMM yyyy').format(endDate)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: budgetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Total Trip Budget (₹) *',
                      hintText: 'e.g. 35000',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Push Notification Reminder Option
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.notifications_active, color: Color(0xFF0284C7), size: 18),
                                SizedBox(width: 8),
                                Text('Push Notification Reminder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            Switch(
                              value: scheduleReminder,
                              activeThumbColor: const Color(0xFF0284C7),
                              onChanged: (v) => setModalState(() => scheduleReminder = v),
                            ),
                          ],
                        ),
                        if (scheduleReminder)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Alert on ${DateFormat('dd MMM').format(startDate)} at ${reminderTime.format(context)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final picked = await showTimePicker(context: context, initialTime: reminderTime);
                                  if (picked != null) setModalState(() => reminderTime = picked);
                                },
                                child: const Text('Change Time'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Trip Notes / Highlights (Optional)',
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
                        final dest = destCtrl.text.trim();
                        final budget = double.tryParse(budgetCtrl.text.trim()) ?? 0.0;

                        if (title.isEmpty || dest.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a trip name and destination')),
                          );
                          return;
                        }

                        final newTrip = TripPlanModel(
                          title: title,
                          destination: dest,
                          destinationMapUrl: mapUrlCtrl.text.trim().isNotEmpty ? mapUrlCtrl.text.trim() : null,
                          startDate: DateFormat('yyyy-MM-dd').format(startDate),
                          endDate: DateFormat('yyyy-MM-dd').format(endDate),
                          budget: budget,
                          coverCategory: selectedCategory,
                          status: 'planned',
                          notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                        );

                        await TripRepository.insertTrip(newTrip);

                        // Schedule Push Notification if enabled
                        if (scheduleReminder) {
                          final notifDateTime = DateTime(
                            startDate.year,
                            startDate.month,
                            startDate.day,
                            reminderTime.hour,
                            reminderTime.minute,
                          );
                          await NotificationService.instance.scheduleTripNotification(
                            tripId: newTrip.id,
                            tripTitle: newTrip.title,
                            destination: newTrip.destination,
                            scheduledDateTime: notifDateTime,
                          );
                        }

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          _loadAllData();
                        }
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Create Trip Plan'),
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

  // =================== SAVE GLOBAL PLACE MODAL ===================

  void _showSavePlaceModal() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final mapUrlCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'Attraction';

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
                const Text('Save Location to Store 📍', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Place Name *', prefixIcon: Icon(Icons.place), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address / Area', prefixIcon: Icon(Icons.location_city), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mapUrlCtrl,
                  decoration: const InputDecoration(labelText: 'Google Maps Link (Optional)', prefixIcon: Icon(Icons.link), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final place = TripLocationItem(
                        tripId: 'global',
                        name: name,
                        category: category,
                        address: addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null,
                        mapUrl: mapUrlCtrl.text.trim().isNotEmpty ? mapUrlCtrl.text.trim() : null,
                        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                      );
                      await TripRepository.insertTripLocation(place);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        _loadAllData();
                      }
                    },
                    child: const Text('Save Location'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // =================== MAIN SCREEN BUILD ===================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.flight_takeoff_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 10),
            Text('Trip Planner & Maps Hub 🗺️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Plan New Trip',
            onPressed: _showCreateTripModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Quick Search & 1-Tap Map Redirection Bar
          _buildQuickMapSearchBar(isDark),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0284C7),
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              indicatorColor: const Color(0xFF0284C7),
              indicatorWeight: 3,
              tabs: [
                Tab(
                  icon: const Icon(Icons.card_travel, size: 20),
                  text: 'Trips (${_trips.length})',
                ),
                Tab(
                  icon: const Icon(Icons.pin_drop_outlined, size: 20),
                  text: 'Location Store (${_allPlaces.length})',
                ),
                Tab(
                  icon: const Icon(Icons.directions_car_outlined, size: 20),
                  text: 'Directions Hub',
                ),
              ],
            ),
          ),

          // Tab View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTripsTab(isDark),
                      _buildLocationStoreTab(isDark),
                      _buildDirectionsHubTab(isDark),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        onPressed: () {
          if (_tabController.index == 0) {
            _showCreateTripModal();
          } else if (_tabController.index == 1) {
            _showSavePlaceModal();
          } else {
            _handleQuickGetDirections();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Plan Trip' : (_tabController.index == 1 ? 'Save Place' : 'Navigate')),
      ),
    );
  }

  // =================== QUICK SEARCH BAR ===================

  Widget _buildQuickMapSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _quickSearchController,
              decoration: InputDecoration(
                hintText: 'Search place, hotel, or paste map link...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0284C7)),
                suffixIcon: _quickSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _quickSearchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _handleQuickMapSearch(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            icon: const Icon(Icons.map, color: Colors.white, size: 20),
            tooltip: 'Open in Google Maps',
            onPressed: _handleQuickMapSearch,
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            icon: const Icon(Icons.directions, color: Colors.white, size: 20),
            tooltip: 'Get Turn-by-turn Directions',
            onPressed: _handleQuickGetDirections,
          ),
        ],
      ),
    );
  }

  // =================== TAB 1: TRIPS LIST ===================

  Widget _buildTripsTab(bool isDark) {
    final filteredTrips = _trips.where((t) {
      if (_tripFilter == 'all') return true;
      return t.status == _tripFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Trips', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Ongoing ✈️', 'ongoing'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Planned 🗓️', 'planned'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed ✅', 'completed'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (filteredTrips.isEmpty)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.flight_takeoff_rounded, size: 54, color: Color(0xFF0284C7)),
                        const SizedBox(height: 12),
                        const Text('No trips found.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Tap "+ Plan Trip" below to create your vacation plan!', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showCreateTripModal,
                          icon: const Icon(Icons.add),
                          label: const Text('Plan a Trip'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredTrips.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (ctx, i) {
                  final trip = filteredTrips[i];
                  return _buildTripCard(trip, isDark);
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _tripFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF0284C7).withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF0284C7) : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
      onSelected: (val) {
        if (val) setState(() => _tripFilter = value);
      },
    );
  }

  Widget _buildTripCard(TripPlanModel trip, bool isDark) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TripDetailScreen(initialTrip: trip)),
          );
          if (res == true) _loadAllData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_getTripThemeIcon(trip.coverCategory), color: const Color(0xFF0284C7), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.redAccent, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                trip.destination,
                                style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_active_outlined, color: Color(0xFF0284C7), size: 20),
                    tooltip: 'Set Trip Push Reminder',
                    onPressed: () => _showTripReminderModal(trip),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Delete Trip',
                    onPressed: () => _confirmDeleteTrip(trip),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.date_range, size: 15, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.startDate} to ${trip.endDate}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  Text(
                    'Budget: ₹${trip.budget.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('🗺️ Launching Maps for ${trip.destination}...')),
                        );
                        await MapRedirectionService.openLocationInMaps(
                          locationName: trip.destination,
                          customMapUrl: trip.destinationMapUrl,
                        );
                      },
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('Open in Maps'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => TripDetailScreen(initialTrip: trip)),
                        );
                        if (res == true) _loadAllData();
                      },
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Track Trip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTripThemeIcon(String category) {
    switch (category) {
      case 'beach':
        return Icons.beach_access;
      case 'mountains':
        return Icons.terrain;
      case 'city':
        return Icons.location_city;
      case 'roadtrip':
        return Icons.directions_car;
      case 'heritage':
        return Icons.account_balance;
      default:
        return Icons.flight_takeoff;
    }
  }

  // =================== TAB 2: LOCATION STORE ===================

  Widget _buildLocationStoreTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Saved Locations & Spots 📍', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  if (_allPlaces.isNotEmpty)
                    TextButton(
                      onPressed: _confirmClearAllDemoPlaces,
                      child: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  TextButton.icon(
                    onPressed: _showSavePlaceModal,
                    icon: const Icon(Icons.add_location, size: 18),
                    label: const Text('Save Place'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_allPlaces.isEmpty)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.pin_drop_outlined, size: 50, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No saved places yet.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      const Text(
                        'Save favorite spots or destinations with instant 1-tap map launch.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: _showSavePlaceModal,
                        icon: const Icon(Icons.add_location),
                        label: const Text('Add a Place'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allPlaces.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final place = _allPlaces[i];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.15),
                          child: const Icon(Icons.location_on, color: Color(0xFF8B5CF6)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(place.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              if (place.address != null && place.address!.isNotEmpty)
                                Text(place.address!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              if (place.notes != null && place.notes!.isNotEmpty)
                                Text(place.notes!, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('🗺️ Launching Maps for "${place.name}"...')),
                            );
                            await MapRedirectionService.openLocationInMaps(
                              locationName: place.name,
                              address: place.address,
                              customMapUrl: place.mapUrl,
                            );
                          },
                          icon: const Icon(Icons.directions, size: 16),
                          label: const Text('Open Maps'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          tooltip: 'Delete Place',
                          onPressed: () => _confirmDeletePlace(place),
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
    );
  }

  // =================== TAB 3: DIRECTIONS HUB ===================

  Widget _buildDirectionsHubTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Turn-by-Turn Navigation Hub 🚗', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Launch direct navigation in Google Maps or your native GPS app.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 18),

                  TextField(
                    controller: _originController,
                    decoration: InputDecoration(
                      labelText: 'Start Origin (Optional)',
                      hintText: 'Leave empty for Current GPS Location',
                      prefixIcon: const Icon(Icons.my_location, color: Colors.blue),
                      suffixIcon: _originController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _originController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),

                  Center(
                    child: IconButton(
                      icon: const Icon(Icons.swap_vert_rounded, color: Color(0xFF0284C7)),
                      tooltip: 'Swap Origin and Destination',
                      onPressed: () {
                        final temp = _originController.text;
                        setState(() {
                          _originController.text = _destinationController.text;
                          _destinationController.text = temp;
                        });
                      },
                    ),
                  ),

                  TextField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      labelText: 'Destination Place / Address *',
                      hintText: 'e.g. Chennai, Airport, Hotel Seaside',
                      prefixIcon: const Icon(Icons.pin_drop, color: Colors.redAccent),
                      suffixIcon: _destinationController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _destinationController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),

                  const Text('Travel Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'driving', icon: Icon(Icons.directions_car), label: Text('Drive')),
                      ButtonSegment(value: 'transit', icon: Icon(Icons.directions_bus), label: Text('Transit')),
                      ButtonSegment(value: 'walking', icon: Icon(Icons.directions_walk), label: Text('Walk')),
                    ],
                    selected: {_travelMode},
                    onSelectionChanged: (val) {
                      setState(() => _travelMode = val.first);
                    },
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final dest = _destinationController.text.trim();
                        if (dest.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a destination place or city (e.g. Chennai)')),
                          );
                          return;
                        }
                        final origin = _originController.text.trim();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🚀 Opening turn-by-turn navigation to "$dest"...'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        await MapRedirectionService.openDirectionsToDestination(
                          destination: dest,
                          origin: origin.isEmpty ? null : origin,
                          travelMode: _travelMode,
                        );
                      },
                      icon: const Icon(Icons.navigation),
                      label: const Text('Start Navigation in Maps App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
