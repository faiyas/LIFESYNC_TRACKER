import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../database/app_database.dart';
import '../../models/my_day_models.dart';
import '../../providers/app_provider.dart';
import '../../services/app_time_service.dart';
import '../../services/dynamic_scheduling_engine.dart';
import '../../services/google_sheets_backup_service.dart';
import '../../services/my_day_category_service.dart';
import '../../services/my_day_reminder_service.dart';
import 'widgets/add_edit_my_day_task_dialog.dart';
import 'widgets/daily_balance_dialog.dart';
import 'widgets/daily_overview_header.dart';
import 'widgets/focus_timer_dialog.dart';
import 'widgets/live_timeline_view.dart';
import 'widgets/missed_tasks_banner.dart';
import 'widgets/my_day_preferences_sheet.dart';

/// Main My Day / Daily Planner Screen
class MyDayScreen extends StatefulWidget {
  const MyDayScreen({super.key});

  @override
  State<MyDayScreen> createState() => _MyDayScreenState();
}

class _MyDayScreenState extends State<MyDayScreen> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<DateTime>? _timeSubscription;

  DateTime _selectedDate = DateTime.now();
  MyDayPreferences _preferences = MyDayPreferences(profileId: 'default_profile');
  List<MyDayTask> _allTasks = [];
  DailyScheduleResult? _scheduleResult;
  bool _isLoading = true;
  bool _isSyncingSheets = false;
  int _lastDataVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
    _timeSubscription = AppTimeService.instance.timeStream.listen((_) {
      if (mounted) {
        _recalculateSchedule();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadData();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timeSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await AppDatabase.instance.database;

      // 1. Load preferences & dynamic categories
      await MyDayCategoryService.instance.getCategories();
      final prefRows = await db.query('my_day_preferences', where: 'id = ?', whereArgs: ['default_my_day_prefs']);
      if (prefRows.isNotEmpty) {
        _preferences = MyDayPreferences.fromMap(prefRows.first);
      } else {
        _preferences = MyDayPreferences(profileId: 'default_profile');
        await db.insert('my_day_preferences', _preferences.toMap());
      }

      // 2. Load all tasks
      final taskRows = await db.query('my_day_tasks', orderBy: 'createdAt ASC');
      _allTasks = taskRows.map((e) => MyDayTask.fromMap(e)).toList();

      // 3. Compute dynamic schedule
      _recalculateSchedule();
    } catch (e) {
      debugPrint('Error loading My Day data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _recalculateSchedule() {
    _scheduleResult = DynamicSchedulingEngine.instance.computeSchedule(
      date: _selectedDate,
      allTasks: _allTasks,
      preferences: _preferences,
      deviceTime: AppTimeService.instance.now,
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
    _recalculateSchedule();
  }

  void _notifyDataChanged() {
    try {
      Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
    } catch (_) {
      GoogleSheetsBackupService.instance.triggerDebouncedSync();
    }
  }

  // ================= Action Handlers =================

  Future<void> _openAddTaskDialog({MyDayTask? taskToEdit}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => AddEditMyDayTaskDialog(
        taskToEdit: taskToEdit,
        targetDate: _selectedDate,
        onSaved: (savedTask) {
          _notifyDataChanged();
          _loadData();
        },
      ),
    );
  }

  Future<void> _openPreferencesSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => MyDayPreferencesSheet(
        initialPreferences: _preferences,
        onSaved: (updated) {
          setState(() => _preferences = updated);
          _notifyDataChanged();
          _recalculateSchedule();
        },
      ),
    );
  }

  void _openBalanceDialog() {
    if (_scheduleResult != null) {
      showDialog(
        context: context,
        builder: (_) => DailyBalanceDialog(scheduleResult: _scheduleResult!),
      );
    }
  }

  Future<void> _openFocusTimerDialog({MyDayTask? task}) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FocusTimerDialog(initialTask: task),
    );
    if (res == true) {
      _notifyDataChanged();
      _loadData();
    }
  }

  Future<void> _toggleTaskComplete(MyDayTask task) async {
    try {
      final db = await AppDatabase.instance.database;
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      bool isNowCompleted = false;

      if (task.recurrenceRule != 'none') {
        // Toggle date in extraDataJson completedDates
        Map<String, dynamic> extra = {};
        if (task.extraDataJson != null && task.extraDataJson!.isNotEmpty) {
          try {
            extra = jsonDecode(task.extraDataJson!);
          } catch (_) {}
        }
        final List<dynamic> rawList = (extra['completedDates'] as List<dynamic>?) ?? [];
        final Set<String> completedDates = rawList.map((e) => e.toString()).toSet();

        if (completedDates.contains(selectedDateStr)) {
          completedDates.remove(selectedDateStr);
          isNowCompleted = false;
        } else {
          completedDates.add(selectedDateStr);
          isNowCompleted = true;
        }
        extra['completedDates'] = completedDates.toList();

        await db.update(
          'my_day_tasks',
          {
            'extraDataJson': jsonEncode(extra),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [task.id],
        );
      } else {
        final newStatus = !task.isCompleted;
        isNowCompleted = newStatus;
        await db.update(
          'my_day_tasks',
          {
            'isCompleted': newStatus ? 1 : 0,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [task.id],
        );
      }

      _notifyDataChanged();
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isNowCompleted ? Icons.check_circle_rounded : Icons.undo_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isNowCompleted ? '🎉 "${task.title}" completed!' : 'Marked "${task.title}" as pending',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: isNowCompleted ? Colors.green : Colors.grey.shade800,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling task complete: $e');
    }
  }

  Future<void> _deleteTask(MyDayTask task) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('my_day_tasks', where: 'id = ?', whereArgs: [task.id]);
      await MyDayReminderService.instance.cancelTaskReminders(task.id);
      _notifyDataChanged();
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${task.title}"')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  Future<void> _moveTaskToNextSlot(MyDayTask task) async {
    // Dynamic scheduler automatically fits it in the next open gap
    final updated = task.copyWith(
      schedulingType: 'flexible',
      startTime: null,
      endTime: null,
    );
    try {
      final db = await AppDatabase.instance.database;
      await db.insert('my_day_tasks', updated.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      _notifyDataChanged();
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved "${task.title}" to next available gap!'), backgroundColor: const Color(0xFF0284C7)),
        );
      }
    } catch (e) {
      debugPrint('Error moving task to next slot: $e');
    }
  }

  Future<void> _moveTaskToTomorrow(MyDayTask task) async {
    final tomorrowStr = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
    final updated = task.copyWith(date: tomorrowStr);

    try {
      final db = await AppDatabase.instance.database;
      await db.insert('my_day_tasks', updated.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      _notifyDataChanged();
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rescheduled "${task.title}" for tomorrow'), backgroundColor: const Color(0xFF8B5CF6)),
        );
      }
    } catch (e) {
      debugPrint('Error moving task to tomorrow: $e');
    }
  }

  Future<void> _syncGoogleSheets() async {
    setState(() => _isSyncingSheets = true);
    final result = await GoogleSheetsBackupService.instance.backupNow();
    if (mounted) {
      setState(() => _isSyncingSheets = false);
      final isSuccess = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? (isSuccess ? '✅ Synced all daily activities & preferences to Google Sheets!' : 'Sync failed')),
          backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeService = AppTimeService.instance;
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == timeService.todayDateString;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
                ),
              ),
              child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'My Day',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(width: 8),
            // Live clock pill in AppBar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF00F2FE)),
                  const SizedBox(width: 4),
                  Text(
                    timeService.formattedTime,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isSyncingSheets)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_sync_rounded),
              tooltip: 'Sync with Google Sheets',
              onPressed: _syncGoogleSheets,
            ),
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            tooltip: 'Deep Focus Mode',
            onPressed: () => _openFocusTimerDialog(),
          ),
        ],
      ),
      body: _isLoading || _scheduleResult == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Daily Overview Header (Greeting, Live Clock, Now/Next, Target Progress)
                    DailyOverviewHeader(
                      selectedDate: _selectedDate,
                      scheduleResult: _scheduleResult!,
                      onOpenPreferences: _openPreferencesSheet,
                      onOpenBalance: _openBalanceDialog,
                      onOpenFocusTimer: () => _openFocusTimerDialog(),
                      onSyncSheets: _syncGoogleSheets,
                      onDateChanged: _onDateChanged,
                      onStartTaskFocus: (task) => _openFocusTimerDialog(task: task),
                      onToggleComplete: _toggleTaskComplete,
                    ),

                    const SizedBox(height: 18),

                    // Missed Tasks Smart Action Banner
                    if (isToday && _scheduleResult!.missedSlots.isNotEmpty)
                      MissedTasksBanner(
                        missedSlots: _scheduleResult!.missedSlots,
                        onCompleteNow: _toggleTaskComplete,
                        onMoveToNextSlot: _moveTaskToNextSlot,
                        onMoveToTomorrow: _moveTaskToTomorrow,
                        onReschedule: (task) => _openAddTaskDialog(taskToEdit: task),
                        onSkip: (task) => _toggleTaskComplete(task),
                      ),

                    // Timeline Title Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dynamic Daily Timeline ⏱️',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () => _openAddTaskDialog(),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Activity'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Vertical Dynamic Timeline
                    LiveTimelineView(
                      scheduleResult: _scheduleResult!,
                      isToday: isToday,
                      scrollController: _scrollController,
                      onToggleComplete: _toggleTaskComplete,
                      onStartFocus: (task) => _openFocusTimerDialog(task: task),
                      onEdit: (task) => _openAddTaskDialog(taskToEdit: task),
                      onDelete: _deleteTask,
                      onMoveToNextSlot: _moveTaskToNextSlot,
                      onAddTask: () => _openAddTaskDialog(),
                    ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddTaskDialog(),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Add Activity', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
