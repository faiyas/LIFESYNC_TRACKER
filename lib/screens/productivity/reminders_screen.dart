import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/notification_service.dart';
import '../../services/app_notification_scheduler.dart';
import '../../services/dynamic_option_service.dart';
import '../../widgets/dynamic_dropdown_field.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Reminder> _reminders = [];
  bool _isLoading = true;
  int _lastDataVersion = -1;

  List<String> reminderCategories = [];

  final advanceOptions = {
    'Exact Time': Duration.zero,
    '10 Minutes Before': const Duration(minutes: 10),
    '1 Hour Before': const Duration(hours: 1),
    '1 Day Before': const Duration(days: 1),
    '2 Days Before': const Duration(days: 2),
    '1 Week Before': const Duration(days: 7),
  };

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadReminders();
      }
    } catch (_) {}
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('reminders', orderBy: 'dateTime ASC');
    final dynamicCats = await DynamicOptionService.instance.getOptions(DynamicOptionService.typeReminderCategory);
    setState(() {
      _reminders = maps.map((e) => Reminder.fromMap(e)).toList();
      reminderCategories = dynamicCats;
      _isLoading = false;
    });
  }

  Future<void> _addReminderDialog() async {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    String category = reminderCategories.isNotEmpty ? reminderCategories.first : 'General';
    String advanceLabel = '1 Day Before';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);

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
                              color: Colors.indigo.withAlpha(38),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.notifications_active_outlined, color: Colors.indigo),
                          ),
                          const SizedBox(width: 12),
                          const Text('New Reminder Alert', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Reminder Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.alarm),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DynamicDropdownField(
                    type: DynamicOptionService.typeReminderCategory,
                    label: 'Category',
                    prefixIcon: Icons.category_outlined,
                    initialValue: category,
                    onChanged: (v) => setModalState(() => category = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: advanceLabel,
                    decoration: InputDecoration(
                      labelText: 'Alert Lead Time (Before Deadline)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.timer_outlined),
                    ),
                    items: advanceOptions.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                    onChanged: (v) => setModalState(() => advanceLabel = v!),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.withAlpha(80)),
                    ),
                    leading: const Icon(Icons.calendar_today_rounded, color: Colors.indigo),
                    title: Text(
                      'Deadline: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')} at ${selectedTime.format(context)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (pickedDate != null && context.mounted) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (pickedTime != null) {
                          setModalState(() {
                            selectedDate = pickedDate;
                            selectedTime = pickedTime;
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (titleController.text.isEmpty) return;

                        final deadlineDateTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        final leadDuration = advanceOptions[advanceLabel] ?? Duration.zero;
                        final scheduledTime = deadlineDateTime.subtract(leadDuration);

                        final rem = Reminder(
                          profileId: 'default_profile',
                          title: titleController.text,
                          dateTime: deadlineDateTime.toIso8601String(),
                          notes: 'Alert ($advanceLabel): ${notesController.text}',
                        );

                        final db = await AppDatabase.instance.database;
                        await db.insert('reminders', rem.toMap());
                        try {
                          if (mounted) {
                            Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                          }
                        } catch (_) {}

                        await NotificationService.instance.scheduleNotification(
                          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                          title: 'Reminder: ${titleController.text}',
                          body: '$category deadline is approaching ($advanceLabel)',
                          scheduledDateTime: scheduledTime,
                        );

                        if (mounted) Navigator.pop(context);
                        _loadReminders();
                      },
                      child: const Text('Schedule Alert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final title = titleController.text.trim().isNotEmpty ? titleController.text.trim() : 'Test Reminder Alert';
                        await NotificationService.instance.showNotification(
                          id: DateTime.now().millisecondsSinceEpoch % 100000,
                          title: '⏰ $title',
                          body: 'This is a test notification for $category ($advanceLabel)',
                        );
                        if (mounted) {
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

  Future<void> _deleteReminder(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    _loadReminders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders & Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.nightlight_round, color: Colors.purpleAccent),
            tooltip: 'Test 11 PM Financial Summary Push',
            onPressed: () async {
              await AppNotificationScheduler.instance.sendInstantFinancialSummaryNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🌙 Sent instant 11:00 PM Financial Summary Push Notification!'),
                    backgroundColor: Colors.purple,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.alarm_on_rounded, color: Colors.lightBlueAccent),
            tooltip: 'Test 6-Hour Pending Tasks Reminder Push',
            onPressed: () async {
              await AppNotificationScheduler.instance.sendInstantTaskReminderNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📋 Sent instant 6-Hour Pending Task Push Reminder!'),
                    backgroundColor: Colors.indigo,
                  ),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReminderDialog,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('Add Reminder'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? const Center(child: Text('No scheduled reminders'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reminders.length,
                  itemBuilder: (context, index) {
                    final r = _reminders[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.indigo.withAlpha(38),
                              child: const Icon(Icons.notifications_active_outlined, color: Colors.indigo, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    r.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Due: ${r.dateTime.substring(0, 16).replaceAll('T', ' ')}${r.notes != null && r.notes!.isNotEmpty ? ' • ${r.notes}' : ''}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _deleteReminder(r.id),
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.delete_outline, color: Colors.grey, size: 20),
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
}
