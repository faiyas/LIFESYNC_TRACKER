import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../database/app_database.dart';
import '../../../models/my_day_models.dart';
import '../../../services/app_time_service.dart';
import '../../../services/my_day_category_service.dart';

/// Modal sheet allowing the user to configure their daily routine preferences
/// and category goals with full CRUD operations directly backed by SQLite database.
class MyDayPreferencesSheet extends StatefulWidget {
  final MyDayPreferences initialPreferences;
  final ValueChanged<MyDayPreferences> onSaved;

  const MyDayPreferencesSheet({
    super.key,
    required this.initialPreferences,
    required this.onSaved,
  });

  @override
  State<MyDayPreferencesSheet> createState() => _MyDayPreferencesSheetState();
}

class _MyDayPreferencesSheetState extends State<MyDayPreferencesSheet> {
  late String _wakeUpTime;
  late String _bedTime;
  late int _bufferMinutes;
  bool _autoBalanceTo24h = true;

  List<MyDayCategoryOption> _categories = [];
  Map<String, double> _targetHoursMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPreferences;
    _wakeUpTime = p.wakeUpTime;
    _bedTime = p.bedTime;
    _bufferMinutes = p.bufferMinutesBetweenTasks;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final cats = await MyDayCategoryService.instance.getCategories(forceRefresh: true);
    _categories = List.from(cats);
    _targetHoursMap = {
      for (final c in _categories) c.key: c.targetHours,
    };
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  double get _totalAllocatedHours {
    double sum = 0.0;
    for (final val in _targetHoursMap.values) {
      sum += val;
    }
    return sum;
  }

  double get _freeFlexibleHours {
    final free = 24.0 - _totalAllocatedHours;
    return free < 0 ? 0.0 : free;
  }

  Future<void> _pickTime({required bool isWakeUp}) async {
    final currentStr = isWakeUp ? _wakeUpTime : _bedTime;
    final currentMin = AppTimeService.timeStringToMinutes(currentStr);
    final initial = TimeOfDay(hour: currentMin ~/ 60, minute: currentMin % 60);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      setState(() {
        if (isWakeUp) {
          _wakeUpTime = '$h:$m';
        } else {
          _bedTime = '$h:$m';
        }
      });
    }
  }

  // ================= 24-Hour Smart Auto-Balancing Logic =================

  void _onSliderChanged({
    required String key,
    required double newValue,
    required double currentValue,
  }) {
    if (!_autoBalanceTo24h) {
      setState(() {
        _targetHoursMap[key] = double.parse(newValue.toStringAsFixed(1));
      });
      return;
    }

    final delta = newValue - currentValue;
    if (delta.abs() < 0.01) return;

    setState(() {
      if (delta > 0) {
        // Increasing hours
        final availableFree = 24.0 - _totalAllocatedHours;
        if (availableFree >= delta) {
          _targetHoursMap[key] = double.parse(newValue.toStringAsFixed(1));
        } else {
          var needed = delta - (availableFree > 0 ? availableFree : 0.0);
          _targetHoursMap[key] = double.parse((currentValue + (availableFree > 0 ? availableFree : 0.0)).toStringAsFixed(1));

          // Look for other flexible donor categories
          final donors = _categories.where((c) => c.key != key && c.isFlexible).map((c) => c.key).toList();

          for (final donorKey in donors) {
            if (needed <= 0.01) break;
            final donorVal = _targetHoursMap[donorKey] ?? 0.0;
            const minVal = 0.5;
            final canDeduct = donorVal - minVal;
            if (canDeduct > 0) {
              final deduct = canDeduct >= needed ? needed : canDeduct;
              _targetHoursMap[donorKey] = double.parse((donorVal - deduct).toStringAsFixed(1));
              final cur = _targetHoursMap[key] ?? 0.0;
              _targetHoursMap[key] = double.parse((cur + deduct).toStringAsFixed(1));
              needed -= deduct;
            }
          }
        }
      } else {
        // Decreasing hours -> freed time goes into Free / Buffer Time
        _targetHoursMap[key] = double.parse(newValue.toStringAsFixed(1));
      }
    });
  }

  /// Distributes remaining free time evenly across flexible categories
  void _distributeRemainingFreeTimeTo24h() {
    final free = 24.0 - _totalAllocatedHours;
    if (free <= 0.1) return;

    final flexibleCats = _categories.where((c) => c.isFlexible).toList();
    if (flexibleCats.isEmpty) return;

    final share = free / flexibleCats.length;
    setState(() {
      for (final c in flexibleCats) {
        final current = _targetHoursMap[c.key] ?? 0.0;
        _targetHoursMap[c.key] = double.parse((current + share).toStringAsFixed(1));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ Remaining free time evenly distributed across all categories!'),
        backgroundColor: Color(0xFF0284C7),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Proportionally scales all categories to sum to exactly 24.0 hours
  void _autoScaleAllToExact24h() {
    final total = _totalAllocatedHours;
    if (total == 0) return;

    final factor = 24.0 / total;
    setState(() {
      for (final c in _categories) {
        final current = _targetHoursMap[c.key] ?? 1.0;
        _targetHoursMap[c.key] = double.parse((current * factor).clamp(0.5, 12.0).toStringAsFixed(1));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚖️ Scaled all targets proportionally to 24 hours!'),
        backgroundColor: Color(0xFF8B5CF6),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ================= CRUD (Create, Update, Delete) Modals =================

  /// CREATE (C): Add a new category keyword into database
  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    double initialTarget = 1.0;
    Color selectedColor = const Color(0xFF06B6D4);
    IconData selectedIcon = Icons.stars_rounded;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Category Keyword', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      hintText: 'e.g. Gym & Fitness, Freelancing, LeetCode',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Daily Target (Hours):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('${initialTarget.toStringAsFixed(1)}h', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                    ],
                  ),
                  Slider(
                    value: initialTarget,
                    min: 0.5,
                    max: 6.0,
                    divisions: 11,
                    activeColor: const Color(0xFF0284C7),
                    onChanged: (v) => setModalState(() => initialTarget = v),
                  ),
                  const SizedBox(height: 10),
                  const Text('Select Theme Color:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      const Color(0xFF06B6D4),
                      const Color(0xFF10B981),
                      const Color(0xFFF59E0B),
                      const Color(0xFFEC4899),
                      const Color(0xFF8B5CF6),
                      const Color(0xFF38BDF8),
                      const Color(0xFFF97316),
                      const Color(0xFF6366F1),
                    ].map((c) {
                      final isSel = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final added = await MyDayCategoryService.instance.addCategory(
        name: nameController.text.trim(),
        targetHours: initialTarget,
        color: selectedColor,
        icon: selectedIcon,
      );
      if (added != null) {
        await _loadCategories();
      }
    }
  }

  /// UPDATE (U): Edit an existing category in database
  Future<void> _showEditCategoryDialog(MyDayCategoryOption category) async {
    final nameController = TextEditingController(text: category.label);
    double target = _targetHoursMap[category.key] ?? category.targetHours;
    Color selectedColor = category.color;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Edit "${category.label}"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Category Label',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Daily Target (Hours):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('${target.toStringAsFixed(1)}h', style: TextStyle(fontWeight: FontWeight.bold, color: selectedColor)),
                    ],
                  ),
                  Slider(
                    value: target.clamp(0.5, 12.0),
                    min: 0.5,
                    max: 12.0,
                    divisions: 23,
                    activeColor: selectedColor,
                    onChanged: (v) => setModalState(() => target = v),
                  ),
                  const SizedBox(height: 10),
                  const Text('Select Theme Color:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      const Color(0xFF06B6D4),
                      const Color(0xFF10B981),
                      const Color(0xFFF59E0B),
                      const Color(0xFFEC4899),
                      const Color(0xFF8B5CF6),
                      const Color(0xFF38BDF8),
                      const Color(0xFFF97316),
                      const Color(0xFF6366F1),
                    ].map((c) {
                      final isSel = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await MyDayCategoryService.instance.updateCategoryDetails(
        id: category.id,
        label: nameController.text.trim(),
        targetHours: target,
        color: selectedColor,
        icon: category.icon,
      );
      await _loadCategories();
    }
  }

  /// DELETE (D): Delete a category keyword from database
  Future<void> _deleteCategory(MyDayCategoryOption cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${cat.label}"?'),
        content: const Text('Are you sure you want to delete this category from your routine?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await MyDayCategoryService.instance.deleteCategory(cat.id);
      await _loadCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${cat.label}" category')),
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    // 1. Update preferences table
    final updated = widget.initialPreferences.copyWith(
      wakeUpTime: _wakeUpTime,
      bedTime: _bedTime,
      targetSleepHours: _targetHoursMap['sleep'] ?? 8.0,
      targetWorkHours: _targetHoursMap['work'] ?? 5.0,
      targetCyberHours: _targetHoursMap['cybersecurity'] ?? 2.0,
      targetReadingHours: _targetHoursMap['reading'] ?? 1.0,
      targetProjectHours: _targetHoursMap['project'] ?? 1.5,
      targetEntertainmentHours: _targetHoursMap['entertainment'] ?? 1.0,
      bufferMinutesBetweenTasks: _bufferMinutes,
    );

    try {
      final db = await AppDatabase.instance.database;
      await db.insert('my_day_preferences', updated.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Batch update category target hours in SQLite database
      await MyDayCategoryService.instance.saveBatchTargets(_targetHoursMap);

      widget.onSaved(updated);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Daily routine preferences and database categories saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final total = _totalAllocatedHours;
    final free = _freeFlexibleHours;
    final isOverallocated = total > 24.05;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: _isLoading
          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          : SingleChildScrollView(
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
                              color: const Color(0xFF0284C7).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.tune_rounded, color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '24-Hour Routine Balancer',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: isDark ? Colors.white70 : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Customize routine times and database-driven activity goals. The dynamic scheduler adjusts your timeline in real time.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 16),

                  // 24-Hour Interactive Multi-Segmented Gauge Card
                  _build24HourGaugeCard(isDark, total, free, isOverallocated),

                  const SizedBox(height: 16),

                  // Auto-Balance Toggle & Quick Presets
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_mode_rounded, size: 18, color: Color(0xFF0284C7)),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Auto-Balance to 24h',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Smoothly redistributes time across database categories',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: _autoBalanceTo24h,
                              activeColor: const Color(0xFF0284C7),
                              onChanged: (v) => setState(() => _autoBalanceTo24h = v),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _distributeRemainingFreeTimeTo24h,
                                icon: const Icon(Icons.flash_on_rounded, size: 14),
                                label: const Text('Distribute Free', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  side: const BorderSide(color: Color(0xFF0284C7)),
                                  foregroundColor: const Color(0xFF0284C7),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _autoScaleAllToExact24h,
                                icon: const Icon(Icons.balance_rounded, size: 14),
                                label: const Text('Scale to 24h', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                                  foregroundColor: const Color(0xFF8B5CF6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _showAddCategoryDialog,
                              tooltip: 'Add Custom Category Keyword',
                              icon: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF0284C7)),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7).withOpacity(0.12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Wake-up and Bedtime Row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(isWakeUp: true),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.wb_sunny_outlined, size: 16, color: Color(0xFFF97316)),
                                    SizedBox(width: 6),
                                    Text('Wake-Up Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF97316))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  AppTimeService.minutesTo12HourString(AppTimeService.timeStringToMinutes(_wakeUpTime)),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(isWakeUp: false),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.bedtime_outlined, size: 16, color: Color(0xFF6366F1)),
                                    SizedBox(width: 6),
                                    Text('Sleep / Bedtime', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  AppTimeService.minutesTo12HourString(AppTimeService.timeStringToMinutes(_bedTime)),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Dynamic Sliders loaded from database & local cache with Edit & Delete actions
                  ..._categories.map((cat) {
                    final currentVal = _targetHoursMap[cat.key] ?? cat.targetHours;
                    return _buildDynamicCategorySlider(
                      category: cat,
                      value: currentVal,
                      isDark: isDark,
                      onEdit: () => _showEditCategoryDialog(cat),
                      onDelete: cat.isDefault ? null : () => _deleteCategory(cat),
                    );
                  }),

                  _buildBufferSlider(isDark),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _savePreferences,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save & Apply 24h Routine', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ================= 24-Hour Visual Gauge Bar =================

  Widget _build24HourGaugeCard(bool isDark, double total, double free, bool isOverallocated) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOverallocated
              ? Colors.redAccent
              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          width: isOverallocated ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isOverallocated ? Icons.warning_amber_rounded : Icons.pie_chart_rounded,
                    size: 16,
                    color: isOverallocated ? Colors.redAccent : const Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '24-Hour Day Allocation',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOverallocated
                      ? Colors.redAccent.withOpacity(0.15)
                      : const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOverallocated
                      ? '⚠️ ${total.toStringAsFixed(1)}h / 24h (+${(total - 24).toStringAsFixed(1)}h)'
                      : '✅ ${total.toStringAsFixed(1)}h / 24h (${free.toStringAsFixed(1)}h free)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isOverallocated ? Colors.redAccent : const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dynamic Segmented Progress Bar across all database categories
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  ..._categories.map((c) {
                    final hours = _targetHoursMap[c.key] ?? c.targetHours;
                    return _buildSegment(hours, c.color);
                  }),
                  if (free > 0) _buildSegment(free, const Color(0xFFE2E8F0)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Dynamic Mini Legend Chips
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ..._categories.map((c) {
                final hours = _targetHoursMap[c.key] ?? c.targetHours;
                return _buildLegendPill(c.label, '${hours.toStringAsFixed(1)}h', c.color, isDark);
              }),
              _buildLegendPill('Free', '${free.toStringAsFixed(1)}h', const Color(0xFF94A3B8), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(double hours, Color color) {
    if (hours <= 0) return const SizedBox.shrink();
    return Expanded(
      flex: (hours * 10).toInt(),
      child: Container(color: color),
    );
  }

  Widget _buildLegendPill(String label, String hours, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $hours',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  // ================= Sliders =================

  Widget _buildDynamicCategorySlider({
    required MyDayCategoryOption category,
    required double value,
    required bool isDark,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(category.icon, size: 16, color: category.color),
                  const SizedBox(width: 6),
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      tooltip: 'Edit Category',
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      tooltip: 'Delete Category',
                      onPressed: onDelete,
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${value.toStringAsFixed(1)}h',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: category.color),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: category.color,
              thumbColor: category.color,
              overlayColor: category.color.withOpacity(0.2),
              inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              trackHeight: 5,
            ),
            child: Slider(
              value: value.clamp(0.0, 12.0),
              min: 0.0,
              max: 12.0,
              divisions: 24,
              onChanged: (newVal) {
                _onSliderChanged(
                  key: category.key,
                  newValue: newVal,
                  currentValue: value,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBufferSlider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⚡ Buffer Minutes Between Tasks',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_bufferMinutes min',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF14B8A6)),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF14B8A6),
              thumbColor: const Color(0xFF14B8A6),
              overlayColor: const Color(0xFF14B8A6).withOpacity(0.2),
              inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              trackHeight: 5,
            ),
            child: Slider(
              value: _bufferMinutes.toDouble().clamp(0.0, 30.0),
              min: 0.0,
              max: 30.0,
              divisions: 6,
              onChanged: (v) => setState(() => _bufferMinutes = v.toInt()),
            ),
          ),
        ],
      ),
    );
  }
}
