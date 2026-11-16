import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';

class HabitStreakData {
  final int currentStreak;
  final int longestStreak;
  final List<bool> last7DaysCompleted; // Index 0 is 6 days ago, Index 6 is today

  const HabitStreakData({
    required this.currentStreak,
    required this.longestStreak,
    required this.last7DaysCompleted,
  });
}

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  List<Habit> _habits = [];
  Map<String, bool> _todayLogs = {};
  Map<String, HabitStreakData> _streakMap = {};
  bool _isLoading = true;
  int _lastDataVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadHabits();
      }
    } catch (_) {}
  }

  Future<void> _loadHabits() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final habitMaps = await db.query('habits');

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayLogMaps = await db.query('habit_logs', where: 'date = ?', whereArgs: [today]);

    final logsMap = <String, bool>{};
    for (var l in todayLogMaps) {
      logsMap[l['habitId'] as String] = (l['status'] ?? 1) == 1;
    }

    // Load streak data for each habit
    final streakDataMap = <String, HabitStreakData>{};
    final habits = habitMaps.map((e) => Habit.fromMap(e)).toList();

    for (final h in habits) {
      final allLogs = await db.query(
        'habit_logs',
        where: 'habitId = ? AND status = 1',
        orderBy: 'date ASC',
      );
      final completedDates = allLogs.map((l) => l['date'] as String).toSet();
      streakDataMap[h.id] = _calculateStreak(completedDates);
    }

    if (mounted) {
      setState(() {
        _habits = habits;
        _todayLogs = logsMap;
        _streakMap = streakDataMap;
        _isLoading = false;
      });
    }
  }

  HabitStreakData _calculateStreak(Set<String> completedDates) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    // 1. Current Streak
    int currentStreak = 0;
    DateTime checkDate;

    if (completedDates.contains(todayStr)) {
      currentStreak = 1;
      checkDate = now.subtract(const Duration(days: 1));
    } else if (completedDates.contains(yesterdayStr)) {
      currentStreak = 1;
      checkDate = now.subtract(const Duration(days: 2));
    } else {
      currentStreak = 0;
      checkDate = now.subtract(const Duration(days: 1));
    }

    if (currentStreak > 0) {
      while (true) {
        final dateStr = DateFormat('yyyy-MM-dd').format(checkDate);
        if (completedDates.contains(dateStr)) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    // 2. Longest Streak
    int longest = 0;
    int temp = 0;
    DateTime? prev;

    final sortedDates = completedDates.map((s) {
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }).whereType<DateTime>().toList()
      ..sort();

    for (final d in sortedDates) {
      if (prev == null) {
        temp = 1;
      } else {
        final diff = d.difference(prev).inDays;
        if (diff == 1) {
          temp++;
        } else if (diff > 1) {
          temp = 1;
        }
      }
      if (temp > longest) longest = temp;
      prev = d;
    }

    if (currentStreak > longest) longest = currentStreak;

    // 3. Last 7 Days (Mon -> Sun or past 7 days)
    final last7 = <bool>[];
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final dStr = DateFormat('yyyy-MM-dd').format(d);
      last7.add(completedDates.contains(dStr));
    }

    return HabitStreakData(
      currentStreak: currentStreak,
      longestStreak: longest,
      last7DaysCompleted: last7,
    );
  }

  Future<void> _addHabitDialog() async {
    final titleController = TextEditingController();
    int targetDays = 7;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_outline, color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Text('Add Daily Habit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Habit Title (e.g. Read 20 mins, Workout)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.fitness_center),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: targetDays,
                  decoration: InputDecoration(
                    labelText: 'Target frequency',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.repeat),
                  ),
                  items: [3, 4, 5, 6, 7].map((d) => DropdownMenuItem(value: d, child: Text('$d days / week'))).toList(),
                  onChanged: (v) => setModalState(() => targetDays = v ?? 7),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) return;

                  final habit = Habit(
                    profileId: 'default_profile',
                    title: titleController.text.trim(),
                    targetDaysPerWeek: targetDays,
                  );

                  final db = await AppDatabase.instance.database;
                  await db.insert('habits', habit.toMap());
                  try {
                    if (mounted) {
                      Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                    }
                  } catch (_) {}
                  if (mounted) Navigator.pop(context);
                  _loadHabits();
                },
                child: const Text('Create Habit', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleHabit(Habit habit) async {
    final db = await AppDatabase.instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isDone = _todayLogs[habit.id] ?? false;

    if (isDone) {
      await db.delete('habit_logs', where: 'habitId = ? AND date = ?', whereArgs: [habit.id, today]);
    } else {
      final log = HabitLog(habitId: habit.id, date: today, status: true);
      await db.insert('habit_logs', log.toMap());
    }
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    _loadHabits();
  }

  Future<void> _deleteHabit(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('habits', where: 'id = ?', whereArgs: [id]);
    await db.delete('habit_logs', where: 'habitId = ?', whereArgs: [id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    _loadHabits();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Tracker & Streaks'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHabitDialog,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New Habit'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? const Center(child: Text('No habits created yet. Tap + to begin!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _habits.length,
                  itemBuilder: (context, index) {
                    final habit = _habits[index];
                    final isDone = _todayLogs[habit.id] ?? false;
                    final streak = _streakMap[habit.id] ??
                        const HabitStreakData(currentStreak: 0, longestStreak: 0, last7DaysCompleted: []);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: isDone
                            ? const BorderSide(color: Colors.green, width: 1.5)
                            : (isDark ? BorderSide(color: Colors.white.withOpacity(0.08)) : BorderSide.none),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _toggleHabit(habit),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isDone ? Colors.green : Colors.grey.withOpacity(0.15),
                                    child: Icon(
                                      isDone ? Icons.check : Icons.circle_outlined,
                                      color: isDone ? Colors.white : Colors.grey,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        habit.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          decoration: isDone ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Target: ${habit.targetDaysPerWeek} days / week',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                // Streak Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: streak.currentStreak > 0
                                        ? Colors.orange.withOpacity(0.15)
                                        : Colors.grey.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 16,
                                        color: streak.currentStreak > 0 ? Colors.orange : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${streak.currentStreak}d',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: streak.currentStreak > 0 ? Colors.orange : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                  onPressed: () => _deleteHabit(habit.id),
                                ),
                              ],
                            ),

                            const Divider(height: 18),

                            // 7-day mini completion history dots
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Best: ${streak.longestStreak} days',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                Row(
                                  children: List.generate(7, (dotIdx) {
                                    final dayName = DateFormat('E')
                                        .format(DateTime.now().subtract(Duration(days: 6 - dotIdx)))
                                        .substring(0, 1);
                                    final isDayDone = streak.last7DaysCompleted.length > dotIdx
                                        ? streak.last7DaysCompleted[dotIdx]
                                        : false;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      child: Column(
                                        children: [
                                          Text(
                                            dayName,
                                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 3),
                                          Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isDayDone ? Colors.green : Colors.grey.withOpacity(0.2),
                                            ),
                                            child: isDayDone
                                                ? const Icon(Icons.check, size: 9, color: Colors.white)
                                                : null,
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ],
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
