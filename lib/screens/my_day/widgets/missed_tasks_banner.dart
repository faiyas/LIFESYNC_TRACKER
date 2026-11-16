import 'package:flutter/material.dart';
import '../../../models/my_day_models.dart';
import '../../../services/dynamic_scheduling_engine.dart';

/// Banner alerting user of missed tasks with smart action options
class MissedTasksBanner extends StatelessWidget {
  final List<ScheduledTimeSlot> missedSlots;
  final Function(MyDayTask) onCompleteNow;
  final Function(MyDayTask) onMoveToNextSlot;
  final Function(MyDayTask) onMoveToTomorrow;
  final Function(MyDayTask) onReschedule;
  final Function(MyDayTask) onSkip;

  const MissedTasksBanner({
    super.key,
    required this.missedSlots,
    required this.onCompleteNow,
    required this.onMoveToNextSlot,
    required this.onMoveToTomorrow,
    required this.onReschedule,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    if (missedSlots.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final firstMissed = missedSlots.first;
    final task = firstMissed.task;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.alarm_off_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Missed Task Alert (${missedSlots.length} pending)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEF4444)),
                    ),
                    Text(
                      '${task.title} (${firstMissed.startTimeStr} – ${firstMissed.endTimeStr})',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Complete Now
              ElevatedButton.icon(
                onPressed: () => onCompleteNow(task),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                label: const Text('Complete Now', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              // Move to Next Available Slot
              OutlinedButton.icon(
                onPressed: () => onMoveToNextSlot(task),
                icon: const Icon(Icons.fast_forward_rounded, size: 15),
                label: const Text('Next Open Slot', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              // Move to Tomorrow
              OutlinedButton.icon(
                onPressed: () => onMoveToTomorrow(task),
                icon: const Icon(Icons.next_plan_outlined, size: 15),
                label: const Text('Tomorrow', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF8B5CF6),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              // Reschedule
              TextButton(
                onPressed: () => onReschedule(task),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('Reschedule', style: TextStyle(fontSize: 11)),
              ),

              // Skip
              TextButton(
                onPressed: () => onSkip(task),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: Colors.grey),
                child: const Text('Skip', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
