import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../database/app_database.dart';
import '../../../models/my_day_models.dart';
import '../../../services/app_time_service.dart';
import '../../../services/my_day_category_service.dart';
import '../../../services/my_day_reminder_service.dart';

/// Comprehensive modal dialog for creating or editing dynamic daily tasks
class AddEditMyDayTaskDialog extends StatefulWidget {
  final MyDayTask? taskToEdit;
  final DateTime targetDate;
  final ValueChanged<MyDayTask> onSaved;

  const AddEditMyDayTaskDialog({
    super.key,
    this.taskToEdit,
    required this.targetDate,
    required this.onSaved,
  });

  @override
  State<AddEditMyDayTaskDialog> createState() => _AddEditMyDayTaskDialogState();
}

class _AddEditMyDayTaskDialogState extends State<AddEditMyDayTaskDialog> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  // Cyber specific
  final _cyberTopicController = TextEditingController();
  final _cyberInstructorController = TextEditingController();
  final _cyberDoubtsController = TextEditingController();
  bool _autoCreateCyberRevisionTasks = true;

  // Travel specific
  String _travelRouteType = 'home_to_work';
  String _travelMode = 'driving';

  String _category = 'general';
  String _schedulingType = 'flexible'; // 'fixed' vs 'flexible'
  String? _startTime = '09:00';
  String? _endTime = '10:00';
  int _durationMinutes = 60;
  String _priority = 'medium';
  int _importanceScore = 5;
  String _recurrenceRule = 'none';
  List<int> _recurrenceDays = [];
  int? _reminderBeforeMinutes = 15;
  bool _reminderAtStart = true;

  List<MyDayCategoryOption> _availableCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.taskToEdit != null) {
      final t = widget.taskToEdit!;
      _titleController.text = t.title;
      _notesController.text = t.notes ?? '';
      _category = t.category;
      _schedulingType = t.schedulingType;
      _startTime = t.startTime;
      _endTime = t.endTime;
      _durationMinutes = t.durationMinutes;
      _priority = t.priority;
      _importanceScore = t.importanceScore;
      _recurrenceRule = t.recurrenceRule;
      _reminderBeforeMinutes = t.reminderBeforeMinutes;
      _reminderAtStart = t.reminderAtStart;

      if (t.recurrenceDays != null) {
        _recurrenceDays = t.recurrenceDays!.split(',').map((e) => int.tryParse(e.trim()) ?? 1).toList();
      }

      final cyber = t.cyberDetails;
      if (cyber != null) {
        _cyberTopicController.text = cyber.topic ?? '';
        _cyberInstructorController.text = cyber.instructor ?? '';
        _cyberDoubtsController.text = cyber.doubts ?? '';
      }

      final travel = t.travelDetails;
      if (travel != null) {
        _travelRouteType = travel.routeType;
        _travelMode = travel.mode;
      }
    }
  }

  Future<void> _loadCategories() async {
    final cats = await MyDayCategoryService.instance.getCategories();
    if (mounted) {
      setState(() {
        _availableCategories = cats;
      });
    }
  }

  Future<void> _showAddCustomCategory() async {
    final nameCtrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Custom Activity Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Gym & Fitness, Freelancing, LeetCode',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Add Category'),
          ),
        ],
      ),
    );

    if (res != null && res.isNotEmpty) {
      final added = await MyDayCategoryService.instance.addCategory(
        name: res,
        targetHours: 1.0,
        color: const Color(0xFF06B6D4),
        icon: Icons.star_rounded,
      );
      if (added != null) {
        await _loadCategories();
        setState(() {
          _category = added.key;
          if (_titleController.text.isEmpty) {
            _titleController.text = added.label;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _cyberTopicController.dispose();
    _cyberInstructorController.dispose();
    _cyberDoubtsController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final currentStr = isStart ? (_startTime ?? '09:00') : (_endTime ?? '10:00');
    final min = AppTimeService.timeStringToMinutes(currentStr);
    final initial = TimeOfDay(hour: min ~/ 60, minute: min % 60);

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      setState(() {
        if (isStart) {
          _startTime = '$h:$m';
          if (_endTime != null) {
            final startM = picked.hour * 60 + picked.minute;
            final endM = AppTimeService.timeStringToMinutes(_endTime!);
            if (endM > startM) {
              _durationMinutes = endM - startM;
            }
          }
        } else {
          _endTime = '$h:$m';
          if (_startTime != null) {
            final startM = AppTimeService.timeStringToMinutes(_startTime!);
            final endM = picked.hour * 60 + picked.minute;
            if (endM > startM) {
              _durationMinutes = endM - startM;
            }
          }
        }
      });
    }
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an activity title')),
      );
      return;
    }

    String? extraJson;
    if (_category == 'cybersecurity') {
      final cyber = CyberActivityDetails(
        topic: _cyberTopicController.text.trim(),
        instructor: _cyberInstructorController.text.trim(),
        doubts: _cyberDoubtsController.text.trim(),
      );
      extraJson = jsonEncode(cyber.toMap());
    } else if (_category == 'travel') {
      final travel = TravelLegDetails(
        routeType: _travelRouteType,
        origin: _travelRouteType.startsWith('home') ? 'Home' : 'Work/Class',
        destination: _travelRouteType.endsWith('home') ? 'Home' : 'Destination',
        mode: _travelMode,
      );
      extraJson = jsonEncode(travel.toMap());
    }

    final dateStr = AppTimeService.instance.todayDateString;

    final task = (widget.taskToEdit != null)
        ? widget.taskToEdit!.copyWith(
            title: title,
            category: _category,
            schedulingType: _schedulingType,
            startTime: _schedulingType == 'fixed' ? _startTime : null,
            endTime: _schedulingType == 'fixed' ? _endTime : null,
            durationMinutes: _durationMinutes,
            priority: _priority,
            importanceScore: _importanceScore,
            notes: _notesController.text.trim(),
            recurrenceRule: _recurrenceRule,
            recurrenceDays: _recurrenceDays.isNotEmpty ? _recurrenceDays.join(',') : null,
            reminderBeforeMinutes: _reminderBeforeMinutes,
            reminderAtStart: _reminderAtStart,
            extraDataJson: extraJson,
          )
        : MyDayTask(
            profileId: 'default_profile',
            title: title,
            category: _category,
            schedulingType: _schedulingType,
            date: dateStr,
            startTime: _schedulingType == 'fixed' ? _startTime : null,
            endTime: _schedulingType == 'fixed' ? _endTime : null,
            durationMinutes: _durationMinutes,
            priority: _priority,
            importanceScore: _importanceScore,
            notes: _notesController.text.trim(),
            recurrenceRule: _recurrenceRule,
            recurrenceDays: _recurrenceDays.isNotEmpty ? _recurrenceDays.join(',') : null,
            reminderBeforeMinutes: _reminderBeforeMinutes,
            reminderAtStart: _reminderAtStart,
            extraDataJson: extraJson,
          );

    try {
      final db = await AppDatabase.instance.database;
      await db.insert('my_day_tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await MyDayReminderService.instance.scheduleTaskReminders(task);

      // If Cybersecurity and auto-create revision is checked, spawn flexible follow-up tasks!
      if (widget.taskToEdit == null && _category == 'cybersecurity' && _autoCreateCyberRevisionTasks) {
        final revTask1 = MyDayTask(
          profileId: 'default_profile',
          title: 'Cyber Revision: ${title}',
          category: 'reading',
          schedulingType: 'flexible',
          date: dateStr,
          durationMinutes: 30,
          priority: 'high',
          importanceScore: 8,
          notes: 'Review class notes and topics from today\'s class.',
        );
        final revTask2 = MyDayTask(
          profileId: 'default_profile',
          title: 'Cyber Lab Practice: ${title}',
          category: 'project',
          schedulingType: 'flexible',
          date: dateStr,
          durationMinutes: 45,
          priority: 'high',
          importanceScore: 8,
          notes: 'Practice hands-on tools and commands covered in class.',
        );
        await db.insert('my_day_tasks', revTask1.toMap());
        await db.insert('my_day_tasks', revTask2.toMap());
      }

      widget.onSaved(task);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.taskToEdit != null ? 'Activity updated' : 'Activity scheduled dynamically!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving my_day_task: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F2FE).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_task_rounded, color: Color(0xFF00F2FE)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.taskToEdit != null ? 'Edit Activity' : 'Add Daily Activity',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),

            const SizedBox(height: 16),

            // Title input
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Activity Name / Goal',
                hintText: 'e.g. Cybersecurity Class, Part-Time Job, Project Code',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                prefixIcon: const Icon(Icons.edit_outlined),
              ),
            ),

            const SizedBox(height: 14),

            // Category Dropdown
            DropdownButtonFormField<String>(
              value: _availableCategories.any((c) => c.key == _category) ? _category : (_availableCategories.isNotEmpty ? _availableCategories.first.key : _category),
              decoration: InputDecoration(
                labelText: 'Activity Category',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                prefixIcon: Icon(
                  MyDayCategoryService.instance.getCategoryIcon(_category),
                  color: MyDayCategoryService.instance.getCategoryColor(_category),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0284C7)),
                  tooltip: 'Create New Category',
                  onPressed: _showAddCustomCategory,
                ),
              ),
              items: _availableCategories.map((c) {
                return DropdownMenuItem(
                  value: c.key,
                  child: Row(
                    children: [
                      Icon(c.icon, size: 16, color: c.color),
                      const SizedBox(width: 8),
                      Text(
                        c.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _category = val;
                    final match = _availableCategories.firstWhere((c) => c.key == val, orElse: () => _availableCategories.first);
                    if (_titleController.text.isEmpty && val != 'general') {
                      _titleController.text = match.label;
                    }
                  });
                }
              },
            ),

            const SizedBox(height: 14),

            // Scheduling Type Segmented Button: Fixed vs Flexible
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _schedulingType = 'fixed'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _schedulingType == 'fixed' ? Colors.indigo.withOpacity(0.15) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _schedulingType == 'fixed' ? Colors.indigoAccent : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.lock_clock_rounded, color: Colors.indigoAccent, size: 20),
                          SizedBox(height: 4),
                          Text('Fixed Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigoAccent)),
                          Text('Locked time window', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _schedulingType = 'flexible'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _schedulingType == 'flexible' ? const Color(0xFF00F2FE).withOpacity(0.15) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _schedulingType == 'flexible' ? const Color(0xFF00F2FE) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.bolt_rounded, color: Color(0xFF00F2FE), size: 20),
                          SizedBox(height: 4),
                          Text('Dynamic / Flexible', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00F2FE))),
                          Text('Auto-fits in gaps', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Time & Duration Pickers
            if (_schedulingType == 'fixed') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(isStart: true),
                      icon: const Icon(Icons.access_time_rounded, size: 16),
                      label: Text('Start: ${_startTime != null ? AppTimeService.minutesTo12HourString(AppTimeService.timeStringToMinutes(_startTime!)) : '--'}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(isStart: false),
                      icon: const Icon(Icons.access_time_filled_rounded, size: 16),
                      label: Text('End: ${_endTime != null ? AppTimeService.minutesTo12HourString(AppTimeService.timeStringToMinutes(_endTime!)) : '--'}'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Duration Chips
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimated Duration: ${AppTimeService.formatDurationMinutes(_durationMinutes)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [15, 30, 45, 60, 90, 120, 180].map((mins) {
                      final isSel = _durationMinutes == mins;
                      return ChoiceChip(
                        label: Text(
                          AppTimeService.formatDurationMinutes(mins),
                          style: TextStyle(
                            color: isSel ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: const Color(0xFF0284C7),
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        side: BorderSide(
                          color: isSel ? const Color(0xFF0284C7) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          width: isSel ? 1.5 : 1,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _durationMinutes = mins);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // Cybersecurity Special Section
            if (_category == 'cybersecurity') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF00F2FE).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00F2FE).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security_rounded, size: 16, color: Color(0xFF00F2FE)),
                        SizedBox(width: 6),
                        Text('Cybersecurity Class Module', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00F2FE))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cyberTopicController,
                      decoration: InputDecoration(
                        labelText: 'Topic / Subject (e.g. Network Scanning, SQLi)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cyberInstructorController,
                      decoration: InputDecoration(
                        labelText: 'Instructor / Mentor',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: _autoCreateCyberRevisionTasks,
                      title: const Text('Auto-generate follow-up Revision & Lab Practice tasks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Creates flexible 30m revision and 45m lab tasks in My Day', style: TextStyle(fontSize: 10)),
                      activeColor: const Color(0xFF00F2FE),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _autoCreateCyberRevisionTasks = val ?? true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Travel Special Section
            if (_category == 'travel') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.directions_car_rounded, size: 16, color: Colors.amber),
                        SizedBox(width: 6),
                        Text('Travel / Commute Leg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _travelRouteType,
                      decoration: InputDecoration(labelText: 'Route Leg', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'home_to_work', child: Text('Home ➔ Work')),
                        DropdownMenuItem(value: 'work_to_home', child: Text('Work ➔ Home')),
                        DropdownMenuItem(value: 'home_to_class', child: Text('Home ➔ Class')),
                        DropdownMenuItem(value: 'class_to_home', child: Text('Class ➔ Home')),
                        DropdownMenuItem(value: 'other', child: Text('Other Commute')),
                      ],
                      onChanged: (v) => setState(() => _travelRouteType = v!),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _travelMode,
                      decoration: InputDecoration(labelText: 'Transit Mode', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'driving', child: Text('Driving (Car/Bike)')),
                        DropdownMenuItem(value: 'transit', child: Text('Public Transit (Bus/Train)')),
                        DropdownMenuItem(value: 'walking', child: Text('Walking')),
                        DropdownMenuItem(value: 'biking', child: Text('Bicycle')),
                      ],
                      onChanged: (v) => setState(() => _travelMode = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Priority & Recurrence Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: InputDecoration(labelText: 'Priority', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'high', child: Text('High 🔥')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgent ⚡')),
                    ],
                    onChanged: (v) => setState(() => _priority = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _recurrenceRule,
                    decoration: InputDecoration(labelText: 'Recurrence', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('Once (Today)')),
                      DropdownMenuItem(value: 'daily', child: Text('Every Day')),
                      DropdownMenuItem(value: 'weekdays', child: Text('Weekdays (M-F)')),
                      DropdownMenuItem(value: 'weekends', child: Text('Weekends')),
                      DropdownMenuItem(value: 'custom', child: Text('Specific Days')),
                    ],
                    onChanged: (v) => setState(() => _recurrenceRule = v!),
                  ),
                ),
              ],
            ),

            if (_recurrenceRule == 'custom') ...[
              const SizedBox(height: 8),
              const Text('Select Specific Days:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  {'id': 1, 'label': 'Mon'},
                  {'id': 2, 'label': 'Tue'},
                  {'id': 3, 'label': 'Wed'},
                  {'id': 4, 'label': 'Thu'},
                  {'id': 5, 'label': 'Fri'},
                  {'id': 6, 'label': 'Sat'},
                  {'id': 7, 'label': 'Sun'},
                ].map((d) {
                  final id = d['id'] as int;
                  final isSel = _recurrenceDays.contains(id);
                  return FilterChip(
                    label: Text(
                      d['label'] as String,
                      style: TextStyle(
                        color: isSel ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: const Color(0xFF0284C7),
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSel ? const Color(0xFF0284C7) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _recurrenceDays.add(id);
                        } else {
                          _recurrenceDays.remove(id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 14),

            // Reminders Options
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _reminderBeforeMinutes,
                    decoration: InputDecoration(labelText: 'Reminder', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('None')),
                      DropdownMenuItem(value: 5, child: Text('5 mins before')),
                      DropdownMenuItem(value: 10, child: Text('10 mins before')),
                      DropdownMenuItem(value: 15, child: Text('15 mins before')),
                      DropdownMenuItem(value: 30, child: Text('30 mins before')),
                      DropdownMenuItem(value: 60, child: Text('1 hour before')),
                    ],
                    onChanged: (v) => setState(() => _reminderBeforeMinutes = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CheckboxListTile(
                    value: _reminderAtStart,
                    title: const Text('At start', style: TextStyle(fontSize: 12)),
                    activeColor: const Color(0xFF0284C7),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _reminderAtStart = val ?? true),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes / Preparation Details',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saveTask,
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(widget.taskToEdit != null ? 'Update Activity' : 'Schedule Activity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
