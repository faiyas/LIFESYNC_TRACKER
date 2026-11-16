import 'package:flutter/material.dart';
import '../../../models/my_day_models.dart';
import '../../../services/app_time_service.dart';
import '../../../services/dynamic_scheduling_engine.dart';
import 'task_timeline_card.dart';

/// Vertical dynamic timeline with live "NOW" marker
class LiveTimelineView extends StatelessWidget {
  final DailyScheduleResult scheduleResult;
  final bool isToday;
  final ScrollController scrollController;
  final Function(MyDayTask) onToggleComplete;
  final Function(MyDayTask) onStartFocus;
  final Function(MyDayTask) onEdit;
  final Function(MyDayTask) onDelete;
  final Function(MyDayTask) onMoveToNextSlot;
  final VoidCallback onAddTask;

  const LiveTimelineView({
    super.key,
    required this.scheduleResult,
    required this.isToday,
    required this.scrollController,
    required this.onToggleComplete,
    required this.onStartFocus,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveToNextSlot,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final slots = scheduleResult.slots;
    final currentMin = scheduleResult.currentMinuteOfDay;

    if (slots.isEmpty && scheduleResult.unscheduledTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF00F2FE).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wb_sunny_outlined, size: 48, color: Color(0xFF00F2FE)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your Day is Open! 🌅',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Add fixed commitments (Classes, Work, Travel) or flexible activities (Reading, Projects) and the dynamic engine will organize your day automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAddTask,
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Add Activity'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build ordered list of timeline elements with live "NOW" line inserted once at exact time boundary
    final List<Widget> timelineWidgets = [];
    bool nowLineInserted = false;

    for (final slot in slots) {
      if (isToday && !nowLineInserted && currentMin < slot.startMinute) {
        timelineWidgets.add(_buildLiveNowIndicator(context));
        nowLineInserted = true;
      }
      timelineWidgets.add(_buildTimelineItem(context, slot, isDark));
    }

    if (isToday && !nowLineInserted) {
      timelineWidgets.add(_buildLiveNowIndicator(context));
    }

    if (scheduleResult.unscheduledTasks.isNotEmpty) {
      timelineWidgets.add(_buildUnscheduledSection(context, isDark));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: timelineWidgets,
    );
  }

  Widget _buildLiveNowIndicator(BuildContext context) {
    final timeService = AppTimeService.instance;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFEF4444),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'NOW — ${timeService.formattedTime}',
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Divider(color: Color(0xFFEF4444), thickness: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, ScheduledTimeSlot slot, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left timeline node & connector
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: slot.isActiveNow
                    ? const Color(0xFF00F2FE)
                    : (slot.isCompleted ? Colors.green : (slot.isFixed ? Colors.indigoAccent : Colors.grey)),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: slot.isActiveNow
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00F2FE).withOpacity(0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            Container(
              width: 2,
              height: 70,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
          ],
        ),
        const SizedBox(width: 12),

        // Right Task Card
        Expanded(
          child: TaskTimelineCard(
            slot: slot,
            onToggleComplete: () => onToggleComplete(slot.task),
            onStartFocus: () => onStartFocus(slot.task),
            onEdit: () => onEdit(slot.task),
            onDelete: () => onDelete(slot.task),
            onMoveToNextSlot: () => onMoveToNextSlot(slot.task),
          ),
        ),
      ],
    );
  }

  Widget _buildUnscheduledSection(BuildContext context, bool isDark) {
    final unscheduled = scheduleResult.unscheduledTasks;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber),
              const SizedBox(width: 8),
              const Text(
                'Unscheduled Tasks (Time Overflow)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The following flexible activities could not fit in today\'s available gaps. You can complete them, adjust schedule, or move them to tomorrow:',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: unscheduled.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final task = unscheduled[idx];
              final categoryColor = MyDayCategoryHelper.getCategoryColor(task.category);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: task.isCompleted ? Colors.green.withOpacity(0.4) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: task.isCompleted,
                      activeColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      onChanged: (_) => onToggleComplete(task),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                              color: task.isCompleted ? (isDark ? Colors.white38 : Colors.black38) : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                MyDayCategoryHelper.categoryLabels[task.category] ?? task.category.toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: categoryColor),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${task.durationMinutes} min',
                                style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      tooltip: 'Focus Mode',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onStartFocus(task),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 18),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        if (val == 'next_slot') onMoveToNextSlot(task);
                        if (val == 'edit') onEdit(task);
                        if (val == 'delete') onDelete(task);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'next_slot', child: Row(children: [Icon(Icons.fast_forward_rounded, size: 16), SizedBox(width: 8), Text('Try Fit in Next Gap')])),
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit Task')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.redAccent, size: 16), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.redAccent))])),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
