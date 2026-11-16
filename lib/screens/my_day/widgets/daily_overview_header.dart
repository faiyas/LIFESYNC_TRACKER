import 'package:flutter/material.dart';
import '../../../models/my_day_models.dart';
import '../../../services/app_time_service.dart';
import '../../../services/dynamic_scheduling_engine.dart';

/// Header widget for My Day displaying live greeting, current clock,
/// active Now & Next task cards, and dynamic category progress metrics.
class DailyOverviewHeader extends StatelessWidget {
  final DateTime selectedDate;
  final DailyScheduleResult scheduleResult;
  final VoidCallback onOpenPreferences;
  final VoidCallback onOpenBalance;
  final VoidCallback onOpenFocusTimer;
  final VoidCallback onSyncSheets;
  final ValueChanged<DateTime> onDateChanged;
  final Function(MyDayTask) onStartTaskFocus;
  final Function(MyDayTask) onToggleComplete;

  const DailyOverviewHeader({
    super.key,
    required this.selectedDate,
    required this.scheduleResult,
    required this.onOpenPreferences,
    required this.onOpenBalance,
    required this.onOpenFocusTimer,
    required this.onSyncSheets,
    required this.onDateChanged,
    required this.onStartTaskFocus,
    required this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeService = AppTimeService.instance;
    final isToday = timeService.todayDateString == AppTimeService.instance.todayDateString &&
        selectedDate.year == timeService.now.year &&
        selectedDate.month == timeService.now.month &&
        selectedDate.day == timeService.now.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Date Switcher & Actions Bar
        _buildDateAndActionsBar(context, isDark, isToday),

        const SizedBox(height: 14),

        // 2. Hero Greeting & Live Time Card
        _buildHeroGreetingCard(context, isDark, isToday),

        const SizedBox(height: 14),

        // 3. Live Now & Next Task Cards
        if (isToday && (scheduleResult.currentSlot != null || scheduleResult.nextSlot != null)) ...[
          _buildNowAndNextCards(context, isDark),
          const SizedBox(height: 14),
        ],

        // 4. Dynamic Category Progress Scroller & Available Time
        _buildCategoryProgressRow(context, isDark),
      ],
    );
  }

  // ================= 1. Date Switcher & Quick Actions =================

  Widget _buildDateAndActionsBar(BuildContext context, bool isDark, bool isToday) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Date Selector Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () => onDateChanged(selectedDate.subtract(const Duration(days: 1))),
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) onDateChanged(picked);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Text(
                        isToday ? 'Today' : AppTimeService.instance.formattedDate,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () => onDateChanged(selectedDate.add(const Duration(days: 1))),
              ),
            ],
          ),
        ),

        // Action Buttons Row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Daily Balance Breakdown
            IconButton(
              icon: const Icon(Icons.pie_chart_outline_rounded),
              tooltip: '24-Hour Balance',
              style: IconButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onOpenBalance,
            ),
            const SizedBox(width: 6),
            // Routine Preferences
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Routine Settings',
              style: IconButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onOpenPreferences,
            ),
            const SizedBox(width: 6),
            // Google Sheets Sync
            IconButton(
              icon: const Icon(Icons.cloud_sync_outlined),
              tooltip: 'Sync with Google Sheets',
              style: IconButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onSyncSheets,
            ),
          ],
        ),
      ],
    );
  }

  // ================= 2. Hero Greeting & Live Time Card =================

  Widget _buildHeroGreetingCard(BuildContext context, bool isDark, bool isToday) {
    final timeService = AppTimeService.instance;
    final remainingFlex = scheduleResult.availableFlexibleMinutes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday ? timeService.greeting : 'Daily Overview',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        isToday ? timeService.formattedTime : AppTimeService.instance.formattedDate,
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            timeService.timeZoneName,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // Live Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00F2FE),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Live Engine',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          // Day Balance Stats Summary
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available Free Time ⚡', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      AppTimeService.formatDurationMinutes(remainingFlex),
                      style: const TextStyle(color: Color(0xFF00F2FE), fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 26, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Completed Today ✅', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      AppTimeService.formatDurationMinutes(scheduleResult.totalCompletedMinutes),
                      style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 26, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Scheduled 📋', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      AppTimeService.formatDurationMinutes(scheduleResult.totalScheduledMinutes),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= 3. Now & Next Live Task Cards =================

  Widget _buildNowAndNextCards(BuildContext context, bool isDark) {
    final current = scheduleResult.currentSlot;
    final next = scheduleResult.nextSlot;

    return Row(
      children: [
        // NOW CARD
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: current != null ? (current.task.isCompleted ? Colors.green.withOpacity(0.6) : const Color(0xFF00F2FE).withOpacity(0.6)) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: current != null ? 1.5 : 1,
              ),
              boxShadow: current != null
                  ? [
                      BoxShadow(
                        color: (current.task.isCompleted ? Colors.green : const Color(0xFF00F2FE)).withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F2FE).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_fill_rounded, size: 12, color: Color(0xFF00F2FE)),
                          SizedBox(width: 4),
                          Text('NOW', style: TextStyle(color: Color(0xFF00F2FE), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    if (current != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => onStartTaskFocus(current.task),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF8B5CF6)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => onToggleComplete(current.task),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: current.task.isCompleted ? Colors.green.withOpacity(0.2) : (isDark ? Colors.white10 : Colors.black12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                current.task.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 16,
                                color: current.task.isCompleted ? Colors.green : (isDark ? Colors.white70 : Colors.black54),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  current != null ? current.task.title : 'Free / Available Time',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: current != null && current.task.isCompleted ? TextDecoration.lineThrough : null,
                    color: current != null && current.task.isCompleted ? (isDark ? Colors.white38 : Colors.black38) : (isDark ? Colors.white : Colors.black87),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  current != null ? '${current.startTimeStr} - ${current.endTimeStr}' : 'No active task right now',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // NEXT CARD
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.skip_next_rounded, size: 12, color: Color(0xFF38BDF8)),
                          SizedBox(width: 4),
                          Text('NEXT', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    if (next != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            next.startTimeStr,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => onToggleComplete(next.task),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: next.task.isCompleted ? Colors.green.withOpacity(0.2) : (isDark ? Colors.white10 : Colors.black12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                next.task.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 14,
                                color: next.task.isCompleted ? Colors.green : (isDark ? Colors.white70 : Colors.black54),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  next != null ? next.task.title : 'All caught up!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: next != null && next.task.isCompleted ? TextDecoration.lineThrough : null,
                    color: next != null && next.task.isCompleted ? (isDark ? Colors.white38 : Colors.black38) : (isDark ? Colors.white : Colors.black87),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  next != null ? '${next.startTimeStr} (${next.durationMinutes}m)' : 'No more tasks scheduled',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ================= 4. Dynamic Category Progress Scroller =================

  Widget _buildCategoryProgressRow(BuildContext context, bool isDark) {
    final summaries = scheduleResult.categorySummaries.values.toList();
    if (summaries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Target vs Completed Progress 🎯',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: -0.2),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: summaries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = summaries[index];
              return Container(
                width: 155,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: item.color.withAlpha(80), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(item.icon, size: 14, color: item.color),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  item.category.toUpperCase(),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: item.color),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(item.progressFraction * 100).toInt()}%',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: item.color),
                        ),
                      ],
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.progressFraction.clamp(0.0, 1.0),
                        backgroundColor: item.color.withAlpha(35),
                        valueColor: AlwaysStoppedAnimation<Color>(item.color),
                        minHeight: 4,
                      ),
                    ),
                    Text(
                      item.progressString,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
