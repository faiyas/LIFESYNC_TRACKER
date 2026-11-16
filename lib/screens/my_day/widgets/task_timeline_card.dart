import 'package:flutter/material.dart';
import '../../../models/my_day_models.dart';
import '../../../services/app_time_service.dart';
import '../../../services/dynamic_scheduling_engine.dart';

/// Interactive card for a scheduled task on the timeline
class TaskTimelineCard extends StatelessWidget {
  final ScheduledTimeSlot slot;
  final VoidCallback onToggleComplete;
  final VoidCallback onStartFocus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveToNextSlot;

  const TaskTimelineCard({
    super.key,
    required this.slot,
    required this.onToggleComplete,
    required this.onStartFocus,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveToNextSlot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final task = slot.task;
    final categoryColor = MyDayCategoryHelper.getCategoryColor(task.category);
    final categoryIcon = MyDayCategoryHelper.categoryIcons[task.category] ?? Icons.event_note;

    final cyberMeta = task.cyberDetails;
    final travelMeta = task.travelDetails;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: slot.isActiveNow
              ? const Color(0xFF00F2FE)
              : (slot.isMissed
                  ? Colors.amber.shade700
                  : (task.isCompleted ? Colors.green.withOpacity(0.4) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)))),
          width: slot.isActiveNow ? 2 : 1,
        ),
        boxShadow: slot.isActiveNow
            ? [
                BoxShadow(
                  color: const Color(0xFF00F2FE).withOpacity(0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Time, Fixed/Dynamic Badge, Priority Tag, Menu
            Row(
              children: [
                // Category Avatar
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(categoryIcon, size: 18, color: categoryColor),
                ),
                const SizedBox(width: 10),

                // Time Duration Range
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${slot.startTimeStr} – ${slot.endTimeStr}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${AppTimeService.formatDurationMinutes(slot.durationMinutes)})',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          // Fixed vs Flexible Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: slot.isFixed ? Colors.indigo.withOpacity(0.15) : const Color(0xFF00F2FE).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(slot.isFixed ? Icons.lock_outline_rounded : Icons.bolt_rounded, size: 10, color: slot.isFixed ? Colors.indigoAccent : const Color(0xFF00F2FE)),
                                const SizedBox(width: 3),
                                Text(
                                  slot.isFixed ? 'Fixed' : 'Dynamic',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: slot.isFixed ? Colors.indigoAccent : const Color(0xFF00F2FE)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Category Pill
                          Text(
                            MyDayCategoryHelper.categoryLabels[task.category] ?? task.category.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: categoryColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Checkbox & Action Menu
                Checkbox(
                  value: task.isCompleted,
                  activeColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  onChanged: (_) => onToggleComplete(),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: (val) {
                    if (val == 'focus') onStartFocus();
                    if (val == 'edit') onEdit();
                    if (val == 'next_slot') onMoveToNextSlot();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'focus', child: Row(children: [Icon(Icons.timer_outlined, size: 18), SizedBox(width: 8), Text('Start Focus Mode')])),
                    const PopupMenuItem(value: 'next_slot', child: Row(children: [Icon(Icons.fast_forward_rounded, size: 18), SizedBox(width: 8), Text('Move to Next Slot')])),
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit Task')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), SizedBox(width: 8), Text('Delete Task', style: TextStyle(color: Colors.redAccent))])),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Task Title (with completed strike-through if done)
            Text(
              task.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? (isDark ? Colors.white38 : Colors.black38) : (isDark ? Colors.white : Colors.black87),
              ),
            ),

            // Cybersecurity Details Snippet
            if (cyberMeta != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00F2FE).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00F2FE).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cyberMeta.topic != null && cyberMeta.topic!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.school_outlined, size: 13, color: Color(0xFF00F2FE)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Topic: ${cyberMeta.topic}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF00F2FE)),
                            ),
                          ),
                        ],
                      ),
                    if (cyberMeta.instructor != null && cyberMeta.instructor!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Instructor: ${cyberMeta.instructor}',
                          style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    if (cyberMeta.revisionTasks.isNotEmpty || cyberMeta.practiceTasks.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 6,
                          children: [
                            if (cyberMeta.revisionTasks.isNotEmpty)
                              Chip(
                                label: Text(
                                  '${cyberMeta.revisionTasks.length} Revision Tasks',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            if (cyberMeta.practiceTasks.isNotEmpty)
                              Chip(
                                label: Text(
                                  '${cyberMeta.practiceTasks.length} Labs/Commands',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Travel Leg Details Snippet
            if (travelMeta != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      travelMeta.mode == 'transit' ? Icons.directions_bus_rounded : Icons.directions_car_rounded,
                      size: 14,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${travelMeta.origin ?? 'Origin'} ➔ ${travelMeta.destination ?? 'Destination'}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Notes snippet
            if (task.notes != null && task.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.notes!,
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? Colors.white54 : Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Active Now or Missed Action Bar
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quick Focus Mode CTA
                OutlinedButton.icon(
                  onPressed: onStartFocus,
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Start Focus', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

                if (slot.isActiveNow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F2FE).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('⚡ In Progress', style: TextStyle(color: Color(0xFF00F2FE), fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else if (slot.isMissed)
                  TextButton.icon(
                    onPressed: onMoveToNextSlot,
                    icon: const Icon(Icons.schedule_send_rounded, size: 14, color: Colors.amber),
                    label: const Text('Move to Next Slot', style: TextStyle(fontSize: 11, color: Colors.amber)),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
