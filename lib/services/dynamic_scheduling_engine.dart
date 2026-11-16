import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/my_day_models.dart';
import 'app_time_service.dart';
import 'my_day_category_service.dart';

/// Representation of a single scheduled item on the 24-hour timeline
class ScheduledTimeSlot {
  final MyDayTask task;
  final int startMinute; // 0..1439
  final int endMinute; // 0..1439
  final String startTimeStr; // "8:00 AM"
  final String endTimeStr; // "10:00 AM"
  final bool isFixed;
  final bool isActiveNow;
  final bool isUpcoming;
  final bool isMissed;
  final bool isCompleted;

  ScheduledTimeSlot({
    required this.task,
    required this.startMinute,
    required this.endMinute,
    required this.startTimeStr,
    required this.endTimeStr,
    required this.isFixed,
    required this.isActiveNow,
    required this.isUpcoming,
    required this.isMissed,
    required this.isCompleted,
  });

  int get durationMinutes => (endMinute - startMinute).clamp(0, 1440);
}

/// Category distribution summary
class CategoryTimeSummary {
  final String category;
  final String label;
  final int plannedMinutes;
  final int completedMinutes;
  final int targetMinutes;
  final Color color;
  final IconData icon;

  CategoryTimeSummary({
    required this.category,
    required this.label,
    required this.plannedMinutes,
    required this.completedMinutes,
    required this.targetMinutes,
    required this.color,
    required this.icon,
  });

  double get progressFraction => targetMinutes > 0 ? (completedMinutes / targetMinutes).clamp(0.0, 1.0) : (plannedMinutes > 0 ? (completedMinutes / plannedMinutes).clamp(0.0, 1.0) : 0.0);
  String get progressString => '${AppTimeService.formatDurationMinutes(completedMinutes)} / ${AppTimeService.formatDurationMinutes(targetMinutes > 0 ? targetMinutes : plannedMinutes)}';
}

/// Result of dynamic schedule calculation
class DailyScheduleResult {
  final DateTime date;
  final List<ScheduledTimeSlot> slots;
  final List<MyDayTask> unscheduledTasks;
  final ScheduledTimeSlot? currentSlot;
  final ScheduledTimeSlot? nextSlot;
  final List<ScheduledTimeSlot> missedSlots;
  final Map<String, CategoryTimeSummary> categorySummaries;
  final int totalScheduledMinutes;
  final int availableFlexibleMinutes;
  final int sleepMinutes;
  final int totalCompletedMinutes;
  final int currentMinuteOfDay;

  DailyScheduleResult({
    required this.date,
    required this.slots,
    required this.unscheduledTasks,
    this.currentSlot,
    this.nextSlot,
    required this.missedSlots,
    required this.categorySummaries,
    required this.totalScheduledMinutes,
    required this.availableFlexibleMinutes,
    required this.sleepMinutes,
    required this.totalCompletedMinutes,
    required this.currentMinuteOfDay,
  });
}

class _TimeInterval {
  int start;
  int end;
  _TimeInterval(this.start, this.end);
  int get duration => (end - start).clamp(0, 1440);
}

/// Dynamic Scheduling Engine
///
/// Implements collision-free gap filling, prioritizes flexible tasks into open windows,
/// recalculates dynamically when tasks or preferences change, and syncs with live device time.
class DynamicSchedulingEngine {
  static final DynamicSchedulingEngine instance = DynamicSchedulingEngine._init();

  DynamicSchedulingEngine._init();

  /// Calculates dynamic schedule for a specific date
  DailyScheduleResult computeSchedule({
    required DateTime date,
    required List<MyDayTask> allTasks,
    required MyDayPreferences preferences,
    DateTime? deviceTime,
  }) {
    final now = deviceTime ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final isToday = DateFormat('yyyy-MM-dd').format(now) == dateStr;
    final isPastDay = date.isBefore(DateTime(now.year, now.month, now.day));
    final currentMinuteOfDay = isToday ? (now.hour * 60 + now.minute) : (isPastDay ? 1440 : 0);

    // 1. Filter tasks applicable to this date (including recurring tasks)
    final dayTasks = _filterTasksForDate(allTasks, date, dateStr);

    // 2. Parse wake-up and bedtime minutes from user preferences
    final wakeUpMin = AppTimeService.timeStringToMinutes(preferences.wakeUpTime);
    var bedTimeMin = AppTimeService.timeStringToMinutes(preferences.bedTime);
    if (bedTimeMin <= wakeUpMin) {
      bedTimeMin = 1439; // default to end of day if midnight
    }

    final sleepDurationMinutes = ((preferences.targetSleepHours * 60).round()).clamp(180, 720);

    // 3. Separate Fixed and Flexible tasks
    final List<MyDayTask> fixedTasks = [];
    final List<MyDayTask> flexibleTasks = [];

    for (final task in dayTasks) {
      if (task.isFixed && task.startTime != null) {
        fixedTasks.add(task);
      } else {
        flexibleTasks.add(task);
      }
    }

    // Sort fixed tasks by start time
    fixedTasks.sort((a, b) {
      final aMin = AppTimeService.timeStringToMinutes(a.startTime ?? '00:00');
      final bMin = AppTimeService.timeStringToMinutes(b.startTime ?? '00:00');
      return aMin.compareTo(bMin);
    });

    // 4. Build fixed occupied intervals and detect open gaps
    final List<_TimeInterval> occupied = [];

    for (final ft in fixedTasks) {
      final start = AppTimeService.timeStringToMinutes(ft.startTime!);
      final end = ft.endTime != null ? AppTimeService.timeStringToMinutes(ft.endTime!) : (start + ft.durationMinutes).clamp(0, 1439);
      occupied.add(_TimeInterval(start, end));
    }

    // Sort occupied intervals
    occupied.sort((a, b) => a.start.compareTo(b.start));

    // Calculate free contiguous open gaps between wakeUpMin and bedTimeMin
    final List<_TimeInterval> openGaps = [];
    int cursor = wakeUpMin;

    for (final occ in occupied) {
      if (occ.start > cursor) {
        openGaps.add(_TimeInterval(cursor, occ.start));
      }
      if (occ.end > cursor) {
        cursor = occ.end;
      }
    }

    if (cursor < bedTimeMin) {
      openGaps.add(_TimeInterval(cursor, bedTimeMin));
    }

    // 5. Prioritize flexible tasks
    flexibleTasks.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final priorityWeight = {'urgent': 4, 'high': 3, 'medium': 2, 'low': 1};
      final pA = priorityWeight[a.priority] ?? 2;
      final pB = priorityWeight[b.priority] ?? 2;
      if (pA != pB) return pB.compareTo(pA);
      if (a.importanceScore != b.importanceScore) return b.importanceScore.compareTo(a.importanceScore);
      return b.durationMinutes.compareTo(a.durationMinutes);
    });

    // 6. Allocate flexible tasks into open gaps
    final List<ScheduledTimeSlot> slots = [];
    final List<MyDayTask> unscheduled = [];
    final bufferMin = preferences.bufferMinutesBetweenTasks;

    // Add fixed tasks as scheduled slots
    for (final ft in fixedTasks) {
      final start = AppTimeService.timeStringToMinutes(ft.startTime!);
      final end = ft.endTime != null ? AppTimeService.timeStringToMinutes(ft.endTime!) : (start + ft.durationMinutes).clamp(0, 1439);
      final isActive = isToday && currentMinuteOfDay >= start && currentMinuteOfDay < end;
      final isUpcoming = (isToday && start > currentMinuteOfDay) || (!isToday && !isPastDay);
      final isMissed = (isPastDay || (isToday && end <= currentMinuteOfDay)) && !ft.isCompleted;

      slots.add(ScheduledTimeSlot(
        task: ft,
        startMinute: start,
        endMinute: end,
        startTimeStr: AppTimeService.minutesTo12HourString(start),
        endTimeStr: AppTimeService.minutesTo12HourString(end),
        isFixed: true,
        isActiveNow: isActive,
        isUpcoming: isUpcoming,
        isMissed: isMissed,
        isCompleted: ft.isCompleted,
      ));
    }

    // Place flexible tasks into available gaps
    for (final fl in flexibleTasks) {
      bool placed = false;
      final requiredDuration = fl.durationMinutes;

      for (int i = 0; i < openGaps.length; i++) {
        final gap = openGaps[i];
        if (gap.duration >= requiredDuration) {
          final slotStart = gap.start;
          final slotEnd = slotStart + requiredDuration;

          final isActive = isToday && currentMinuteOfDay >= slotStart && currentMinuteOfDay < slotEnd;
          final isUpcoming = (isToday && slotStart > currentMinuteOfDay) || (!isToday && !isPastDay);
          final isMissed = (isPastDay || (isToday && slotEnd <= currentMinuteOfDay)) && !fl.isCompleted;

          final scheduledFl = fl.copyWith(
            startTime: AppTimeService.minutesToTimeString(slotStart),
            endTime: AppTimeService.minutesToTimeString(slotEnd),
          );

          slots.add(ScheduledTimeSlot(
            task: scheduledFl,
            startMinute: slotStart,
            endMinute: slotEnd,
            startTimeStr: AppTimeService.minutesTo12HourString(slotStart),
            endTimeStr: AppTimeService.minutesTo12HourString(slotEnd),
            isFixed: false,
            isActiveNow: isActive,
            isUpcoming: isUpcoming,
            isMissed: isMissed,
            isCompleted: fl.isCompleted,
          ));

          // Shrink gap with buffer
          final newGapStart = slotEnd + bufferMin;
          if (newGapStart < gap.end) {
            gap.start = newGapStart;
          } else {
            openGaps.removeAt(i);
          }

          placed = true;
          break;
        }
      }

      if (!placed) {
        unscheduled.add(fl);
      }
    }

    // 7. Sort all slots chronologically
    slots.sort((a, b) => a.startMinute.compareTo(b.startMinute));

    // 8. Find current active slot, next slot, and missed slots
    ScheduledTimeSlot? currentSlot;
    ScheduledTimeSlot? nextSlot;
    final List<ScheduledTimeSlot> missedSlots = [];

    for (final slot in slots) {
      if (slot.isActiveNow) {
        currentSlot = slot;
      }
      if (slot.isMissed) {
        missedSlots.add(slot);
      }
      if (isToday && slot.startMinute > currentMinuteOfDay && nextSlot == null) {
        nextSlot = slot;
      }
    }

    // 9. Compute Category Summaries & Progress
    final categorySummaries = _computeCategorySummaries(slots, preferences);

    // 10. Calculate total flexible available time remaining
    int remainingFreeMinutes = 0;
    for (final gap in openGaps) {
      if (isToday) {
        if (gap.end > currentMinuteOfDay) {
          final effectiveStart = gap.start > currentMinuteOfDay ? gap.start : currentMinuteOfDay;
          remainingFreeMinutes += (gap.end - effectiveStart).clamp(0, 1440);
        }
      } else {
        remainingFreeMinutes += gap.duration;
      }
    }

    int totalScheduled = 0;
    int totalCompleted = 0;
    for (final s in slots) {
      totalScheduled += s.durationMinutes;
      if (s.isCompleted) {
        totalCompleted += (s.task.actualDurationMinutes ?? s.durationMinutes);
      }
    }

    return DailyScheduleResult(
      date: date,
      slots: slots,
      unscheduledTasks: unscheduled,
      currentSlot: currentSlot,
      nextSlot: nextSlot,
      missedSlots: missedSlots,
      categorySummaries: categorySummaries,
      totalScheduledMinutes: totalScheduled,
      availableFlexibleMinutes: remainingFreeMinutes,
      sleepMinutes: sleepDurationMinutes,
      totalCompletedMinutes: totalCompleted,
      currentMinuteOfDay: currentMinuteOfDay,
    );
  }

  List<MyDayTask> _filterTasksForDate(List<MyDayTask> allTasks, DateTime date, String dateStr) {
    final weekday = date.weekday; // 1 = Monday .. 7 = Sunday
    final List<MyDayTask> filtered = [];

    for (final task in allTasks) {
      // 1. Direct date match
      if (task.date == dateStr) {
        if (task.recurrenceRule != 'none') {
          filtered.add(task.copyWith(isCompleted: task.isCompletedForDate(dateStr)));
        } else {
          filtered.add(task);
        }
        continue;
      }

      // 2. Recurrence match
      if (task.recurrenceRule == 'daily') {
        filtered.add(task.copyWith(
          date: dateStr,
          isCompleted: task.isCompletedForDate(dateStr),
        ));
      } else if (task.recurrenceRule == 'weekdays' && weekday <= 5) {
        filtered.add(task.copyWith(
          date: dateStr,
          isCompleted: task.isCompletedForDate(dateStr),
        ));
      } else if (task.recurrenceRule == 'weekends' && weekday >= 6) {
        filtered.add(task.copyWith(
          date: dateStr,
          isCompleted: task.isCompletedForDate(dateStr),
        ));
      } else if (task.recurrenceRule == 'custom' && task.recurrenceDays != null) {
        final days = task.recurrenceDays!.split(',').map((e) => int.tryParse(e.trim()) ?? 0).toList();
        if (days.contains(weekday)) {
          filtered.add(task.copyWith(
            date: dateStr,
            isCompleted: task.isCompletedForDate(dateStr),
          ));
        }
      }
    }

    return filtered;
  }

  Map<String, CategoryTimeSummary> _computeCategorySummaries(List<ScheduledTimeSlot> slots, MyDayPreferences prefs) {
    final Map<String, int> plannedPerCat = {};
    final Map<String, int> completedPerCat = {};

    for (final slot in slots) {
      final cat = slot.task.category;
      plannedPerCat[cat] = (plannedPerCat[cat] ?? 0) + slot.durationMinutes;
      if (slot.isCompleted) {
        completedPerCat[cat] = (completedPerCat[cat] ?? 0) + (slot.task.actualDurationMinutes ?? slot.durationMinutes);
      }
    }

    final targetMinutesMap = {
      'work': (prefs.targetWorkHours * 60).round(),
      'cybersecurity': (prefs.targetCyberHours * 60).round(),
      'reading': (prefs.targetReadingHours * 60).round(),
      'project': (prefs.targetProjectHours * 60).round(),
      'entertainment': (prefs.targetEntertainmentHours * 60).round(),
      'sleep': (prefs.targetSleepHours * 60).round(),
    };

    final Map<String, CategoryTimeSummary> result = {};
    final cachedCats = MyDayCategoryService.instance.cachedCategories;
    final Map<String, MyDayCategoryOption> catMap = {for (final c in cachedCats) c.key: c};

    final allCategoryKeys = <String>{
      ...catMap.keys,
      ...plannedPerCat.keys,
      ...completedPerCat.keys,
      ...MyDayCategoryHelper.categoryLabels.keys,
    };

    for (final cat in allCategoryKeys) {
      final opt = catMap[cat];
      final label = opt?.label ?? MyDayCategoryService.instance.getCategoryLabel(cat);
      final planned = plannedPerCat[cat] ?? 0;
      final completed = completedPerCat[cat] ?? 0;
      final target = opt != null ? (opt.targetHours * 60).round() : (targetMinutesMap[cat] ?? 0);

      if (planned > 0 || target > 0 || completed > 0) {
        result[cat] = CategoryTimeSummary(
          category: cat,
          label: label,
          plannedMinutes: planned,
          completedMinutes: completed,
          targetMinutes: target,
          color: opt?.color ?? MyDayCategoryService.instance.getCategoryColor(cat),
          icon: opt?.icon ?? MyDayCategoryService.instance.getCategoryIcon(cat),
        );
      }
    }

    return result;
  }
}
