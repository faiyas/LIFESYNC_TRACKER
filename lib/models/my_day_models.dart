import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// User's editable daily routine preferences
///
/// NOTE: 8:00 AM, 2h cyber class, 4-5h work, 7-8h sleep are INITIAL defaults,
/// never hardcoded constants. The user can modify them anytime.
class MyDayPreferences {
  final String id;
  final String profileId;
  final String wakeUpTime; // "08:00"
  final String bedTime; // "23:30"
  final double targetSleepHours; // 8.0
  final double targetWorkHours; // 5.0
  final double targetCyberHours; // 2.0
  final double targetReadingHours; // 1.0
  final double targetProjectHours; // 1.5
  final double targetEntertainmentHours; // 1.0
  final int bufferMinutesBetweenTasks; // 10
  final bool isAutoAdjustEnabled;
  final String updatedAt;

  MyDayPreferences({
    String? id,
    required this.profileId,
    this.wakeUpTime = '08:00',
    this.bedTime = '23:30',
    this.targetSleepHours = 8.0,
    this.targetWorkHours = 5.0,
    this.targetCyberHours = 2.0,
    this.targetReadingHours = 1.0,
    this.targetProjectHours = 1.5,
    this.targetEntertainmentHours = 1.0,
    this.bufferMinutesBetweenTasks = 10,
    this.isAutoAdjustEnabled = true,
    String? updatedAt,
  })  : id = id ?? 'default_my_day_prefs',
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'wakeUpTime': wakeUpTime,
      'bedTime': bedTime,
      'targetSleepHours': targetSleepHours,
      'targetWorkHours': targetWorkHours,
      'targetCyberHours': targetCyberHours,
      'targetReadingHours': targetReadingHours,
      'targetProjectHours': targetProjectHours,
      'targetEntertainmentHours': targetEntertainmentHours,
      'bufferMinutesBetweenTasks': bufferMinutesBetweenTasks,
      'isAutoAdjustEnabled': isAutoAdjustEnabled ? 1 : 0,
      'updatedAt': updatedAt,
    };
  }

  factory MyDayPreferences.fromMap(Map<String, dynamic> map) {
    return MyDayPreferences(
      id: map['id'] ?? 'default_my_day_prefs',
      profileId: map['profileId'] ?? 'default_profile',
      wakeUpTime: map['wakeUpTime'] ?? '08:00',
      bedTime: map['bedTime'] ?? '23:30',
      targetSleepHours: (map['targetSleepHours'] as num?)?.toDouble() ?? 8.0,
      targetWorkHours: (map['targetWorkHours'] as num?)?.toDouble() ?? 5.0,
      targetCyberHours: (map['targetCyberHours'] as num?)?.toDouble() ?? 2.0,
      targetReadingHours: (map['targetReadingHours'] as num?)?.toDouble() ?? 1.0,
      targetProjectHours: (map['targetProjectHours'] as num?)?.toDouble() ?? 1.5,
      targetEntertainmentHours: (map['targetEntertainmentHours'] as num?)?.toDouble() ?? 1.0,
      bufferMinutesBetweenTasks: (map['bufferMinutesBetweenTasks'] as num?)?.toInt() ?? 10,
      isAutoAdjustEnabled: (map['isAutoAdjustEnabled'] ?? 1) == 1,
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  MyDayPreferences copyWith({
    String? wakeUpTime,
    String? bedTime,
    double? targetSleepHours,
    double? targetWorkHours,
    double? targetCyberHours,
    double? targetReadingHours,
    double? targetProjectHours,
    double? targetEntertainmentHours,
    int? bufferMinutesBetweenTasks,
    bool? isAutoAdjustEnabled,
  }) {
    return MyDayPreferences(
      id: id,
      profileId: profileId,
      wakeUpTime: wakeUpTime ?? this.wakeUpTime,
      bedTime: bedTime ?? this.bedTime,
      targetSleepHours: targetSleepHours ?? this.targetSleepHours,
      targetWorkHours: targetWorkHours ?? this.targetWorkHours,
      targetCyberHours: targetCyberHours ?? this.targetCyberHours,
      targetReadingHours: targetReadingHours ?? this.targetReadingHours,
      targetProjectHours: targetProjectHours ?? this.targetProjectHours,
      targetEntertainmentHours: targetEntertainmentHours ?? this.targetEntertainmentHours,
      bufferMinutesBetweenTasks: bufferMinutesBetweenTasks ?? this.bufferMinutesBetweenTasks,
      isAutoAdjustEnabled: isAutoAdjustEnabled ?? this.isAutoAdjustEnabled,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }
}

/// Dynamic Task Model for My Day
class MyDayTask {
  final String id;
  final String profileId;
  final String title;
  final String category; // 'cybersecurity', 'work', 'travel', 'reading', 'project', 'routine', 'meals', 'entertainment', 'relaxation', 'sleep', 'breaks', 'general'
  final String schedulingType; // 'fixed', 'flexible'
  final String date; // 'yyyy-MM-dd'
  final String? startTime; // 'HH:mm'
  final String? endTime; // 'HH:mm'
  final int durationMinutes; // e.g. 120
  final String priority; // 'urgent', 'high', 'medium', 'low'
  final int importanceScore; // 1 to 10
  final bool isCompleted;
  final bool isMissed;
  final bool isPinned;
  final String? notes;
  final String recurrenceRule; // 'none', 'daily', 'weekdays', 'weekends', 'weekly', 'custom'
  final String? recurrenceDays; // e.g. '1,3' for Monday and Wednesday
  final int? reminderBeforeMinutes; // 5, 10, 15, 30, 60
  final bool reminderAtStart;
  final bool missedReminderShown;
  final int? actualDurationMinutes;
  final String? extraDataJson;
  final String createdAt;
  final String updatedAt;

  MyDayTask({
    String? id,
    required this.profileId,
    required this.title,
    this.category = 'general',
    this.schedulingType = 'flexible',
    required this.date,
    this.startTime,
    this.endTime,
    required this.durationMinutes,
    this.priority = 'medium',
    this.importanceScore = 5,
    this.isCompleted = false,
    this.isMissed = false,
    this.isPinned = false,
    this.notes,
    this.recurrenceRule = 'none',
    this.recurrenceDays,
    this.reminderBeforeMinutes,
    this.reminderAtStart = true,
    this.missedReminderShown = false,
    this.actualDurationMinutes,
    this.extraDataJson,
    String? createdAt,
    String? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  bool get isFixed => schedulingType == 'fixed';
  bool get isFlexible => schedulingType == 'flexible';

  /// Set of specific 'yyyy-MM-dd' dates on which this recurring task was marked complete
  Set<String> get completedDates {
    if (extraDataJson == null || extraDataJson!.isEmpty) return {};
    try {
      final decoded = jsonDecode(extraDataJson!);
      if (decoded is Map<String, dynamic> && decoded['completedDates'] is List) {
        return (decoded['completedDates'] as List).map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return {};
  }

  /// Checks if this task was completed on a specific target date
  bool isCompletedForDate(String targetDate) {
    if (recurrenceRule != 'none') {
      return completedDates.contains(targetDate);
    }
    return isCompleted;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'category': category,
      'schedulingType': schedulingType,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      'priority': priority,
      'importanceScore': importanceScore,
      'isCompleted': isCompleted ? 1 : 0,
      'isMissed': isMissed ? 1 : 0,
      'isPinned': isPinned ? 1 : 0,
      'notes': notes,
      'recurrenceRule': recurrenceRule,
      'recurrenceDays': recurrenceDays,
      'reminderBeforeMinutes': reminderBeforeMinutes,
      'reminderAtStart': reminderAtStart ? 1 : 0,
      'missedReminderShown': missedReminderShown ? 1 : 0,
      'actualDurationMinutes': actualDurationMinutes,
      'extraDataJson': extraDataJson,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory MyDayTask.fromMap(Map<String, dynamic> map) {
    return MyDayTask(
      id: map['id'],
      profileId: map['profileId'] ?? 'default_profile',
      title: map['title'] ?? 'Untitled Task',
      category: map['category'] ?? 'general',
      schedulingType: map['schedulingType'] ?? 'flexible',
      date: map['date'] ?? '',
      startTime: map['startTime'],
      endTime: map['endTime'],
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
      priority: map['priority'] ?? 'medium',
      importanceScore: (map['importanceScore'] as num?)?.toInt() ?? 5,
      isCompleted: (map['isCompleted'] ?? 0) == 1,
      isMissed: (map['isMissed'] ?? 0) == 1,
      isPinned: (map['isPinned'] ?? 0) == 1,
      notes: map['notes'],
      recurrenceRule: map['recurrenceRule'] ?? 'none',
      recurrenceDays: map['recurrenceDays'],
      reminderBeforeMinutes: (map['reminderBeforeMinutes'] as num?)?.toInt(),
      reminderAtStart: (map['reminderAtStart'] ?? 1) == 1,
      missedReminderShown: (map['missedReminderShown'] ?? 0) == 1,
      actualDurationMinutes: (map['actualDurationMinutes'] as num?)?.toInt(),
      extraDataJson: map['extraDataJson'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  MyDayTask copyWith({
    String? title,
    String? category,
    String? schedulingType,
    String? date,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    String? priority,
    int? importanceScore,
    bool? isCompleted,
    bool? isMissed,
    bool? isPinned,
    String? notes,
    String? recurrenceRule,
    String? recurrenceDays,
    int? reminderBeforeMinutes,
    bool? reminderAtStart,
    bool? missedReminderShown,
    int? actualDurationMinutes,
    String? extraDataJson,
  }) {
    return MyDayTask(
      id: id,
      profileId: profileId,
      title: title ?? this.title,
      category: category ?? this.category,
      schedulingType: schedulingType ?? this.schedulingType,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      priority: priority ?? this.priority,
      importanceScore: importanceScore ?? this.importanceScore,
      isCompleted: isCompleted ?? this.isCompleted,
      isMissed: isMissed ?? this.isMissed,
      isPinned: isPinned ?? this.isPinned,
      notes: notes ?? this.notes,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      reminderBeforeMinutes: reminderBeforeMinutes ?? this.reminderBeforeMinutes,
      reminderAtStart: reminderAtStart ?? this.reminderAtStart,
      missedReminderShown: missedReminderShown ?? this.missedReminderShown,
      actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
      extraDataJson: extraDataJson ?? this.extraDataJson,
      createdAt: createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  /// Helper to get Cybersecurity metadata if this is a Cyber task
  CyberActivityDetails? get cyberDetails {
    if (category != 'cybersecurity' || extraDataJson == null) return null;
    try {
      final map = jsonDecode(extraDataJson!);
      return CyberActivityDetails.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// Helper to get Travel metadata if this is a Travel task
  TravelLegDetails? get travelDetails {
    if (category != 'travel' || extraDataJson == null) return null;
    try {
      final map = jsonDecode(extraDataJson!);
      return TravelLegDetails.fromMap(map);
    } catch (_) {
      return null;
    }
  }
}

/// Metadata for Cybersecurity Activity
class CyberActivityDetails {
  final String? topic;
  final String? instructor;
  final String? doubts;
  final List<String> practiceTasks;
  final List<String> revisionTasks;

  CyberActivityDetails({
    this.topic,
    this.instructor,
    this.doubts,
    this.practiceTasks = const [],
    this.revisionTasks = const [],
  });

  Map<String, dynamic> toMap() => {
        'topic': topic,
        'instructor': instructor,
        'doubts': doubts,
        'practiceTasks': practiceTasks,
        'revisionTasks': revisionTasks,
      };

  factory CyberActivityDetails.fromMap(Map<String, dynamic> map) => CyberActivityDetails(
        topic: map['topic'],
        instructor: map['instructor'],
        doubts: map['doubts'],
        practiceTasks: List<String>.from(map['practiceTasks'] ?? []),
        revisionTasks: List<String>.from(map['revisionTasks'] ?? []),
      );
}

/// Metadata for Travel Leg Activity
class TravelLegDetails {
  final String routeType; // 'home_to_work', 'work_to_home', 'home_to_class', 'class_to_home', 'other'
  final String? origin;
  final String? destination;
  final String mode; // 'driving', 'transit', 'walking', 'biking'

  TravelLegDetails({
    this.routeType = 'other',
    this.origin,
    this.destination,
    this.mode = 'driving',
  });

  Map<String, dynamic> toMap() => {
        'routeType': routeType,
        'origin': origin,
        'destination': destination,
        'mode': mode,
      };

  factory TravelLegDetails.fromMap(Map<String, dynamic> map) => TravelLegDetails(
        routeType: map['routeType'] ?? 'other',
        origin: map['origin'],
        destination: map['destination'],
        mode: map['mode'] ?? 'driving',
      );
}

/// Focus Session Log
class FocusSessionLog {
  final String id;
  final String? taskId;
  final String taskTitle;
  final String category;
  final int plannedMinutes;
  final int focusedMinutes;
  final int pausedMinutes;
  final String startedAt;
  final String endedAt;
  final String status; // 'completed', 'cancelled', 'running'
  final String? notes;

  FocusSessionLog({
    String? id,
    this.taskId,
    required this.taskTitle,
    required this.category,
    required this.plannedMinutes,
    required this.focusedMinutes,
    this.pausedMinutes = 0,
    required this.startedAt,
    required this.endedAt,
    this.status = 'completed',
    this.notes,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'category': category,
        'plannedMinutes': plannedMinutes,
        'focusedMinutes': focusedMinutes,
        'pausedMinutes': pausedMinutes,
        'startedAt': startedAt,
        'endedAt': endedAt,
        'status': status,
        'notes': notes,
      };

  factory FocusSessionLog.fromMap(Map<String, dynamic> map) => FocusSessionLog(
        id: map['id'],
        taskId: map['taskId'],
        taskTitle: map['taskTitle'] ?? 'Focus Session',
        category: map['category'] ?? 'general',
        plannedMinutes: (map['plannedMinutes'] as num?)?.toInt() ?? 25,
        focusedMinutes: (map['focusedMinutes'] as num?)?.toInt() ?? 0,
        pausedMinutes: (map['pausedMinutes'] as num?)?.toInt() ?? 0,
        startedAt: map['startedAt'] ?? DateTime.now().toIso8601String(),
        endedAt: map['endedAt'] ?? DateTime.now().toIso8601String(),
        status: map['status'] ?? 'completed',
        notes: map['notes'],
      );
}

/// Dynamic Database-Driven Category Option for My Day
class MyDayCategoryOption {
  final String id;
  final String key;
  final String label;
  final double targetHours;
  final int colorValue;
  final int iconCodePoint;
  final String iconFontFamily;
  final bool isFlexible;
  final bool isDefault;
  final int sortOrder;
  final bool isActive;
  final String createdAt;

  MyDayCategoryOption({
    String? id,
    required this.key,
    required this.label,
    this.targetHours = 1.0,
    required this.colorValue,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    this.isFlexible = true,
    this.isDefault = false,
    this.sortOrder = 0,
    this.isActive = true,
    String? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Color get color => Color(colorValue);
  IconData get icon => resolveIcon(iconCodePoint, key);

  static IconData resolveIcon(int codePoint, [String? key]) {
    switch (codePoint) {
      case 0xe0e7:
        return Icons.bedtime_outlined;
      case 0xf02f3:
        return Icons.work_outline_rounded;
      case 0xf013f:
        return Icons.security_rounded;
      case 0xe62a:
        return Icons.terminal_rounded;
      case 0xf001f:
        return Icons.menu_book_rounded;
      case 0xf01ae:
        return Icons.sports_esports_rounded;
      case 0xf06b4:
        return Icons.directions_car_rounded;
      case 0xf0118:
        return Icons.restaurant_rounded;
      case 0xf64f:
        return Icons.coffee_rounded;
      case 0xf645:
        return Icons.checklist_rounded;
      case 0xe28d:
      case 0xf715:
        return Icons.fitness_center_rounded;
      case 0xf44e:
        return Icons.stars_rounded;
      case 0xe84f:
        return Icons.code_rounded;
      case 0xf33c:
        return Icons.school_rounded;
      case 0xf05a7:
        return Icons.flight_takeoff_rounded;
      case 0xf0192:
        return Icons.self_improvement_rounded;
      case 0xf37d:
        return Icons.shopping_bag_rounded;
      case 0xf3dc:
        return Icons.sports_soccer_rounded;
      case 0xe404:
        return Icons.movie_filter_rounded;
      case 0xe415:
        return Icons.music_note_rounded;
      default:
        if (key != null) {
          final clean = key.toLowerCase();
          if (clean.contains('sleep') || clean.contains('bed')) return Icons.bedtime_outlined;
          if (clean.contains('work') || clean.contains('job')) return Icons.work_outline_rounded;
          if (clean.contains('cyber') || clean.contains('sec')) return Icons.security_rounded;
          if (clean.contains('project') || clean.contains('dev') || clean.contains('code')) return Icons.terminal_rounded;
          if (clean.contains('read') || clean.contains('study') || clean.contains('learn')) return Icons.menu_book_rounded;
          if (clean.contains('game') || clean.contains('entertain') || clean.contains('play')) return Icons.sports_esports_rounded;
          if (clean.contains('travel') || clean.contains('commute') || clean.contains('drive')) return Icons.directions_car_rounded;
          if (clean.contains('meal') || clean.contains('eat') || clean.contains('food')) return Icons.restaurant_rounded;
          if (clean.contains('break') || clean.contains('coffee') || clean.contains('tea')) return Icons.coffee_rounded;
          if (clean.contains('gym') || clean.contains('fit') || clean.contains('workout')) return Icons.fitness_center_rounded;
        }
        return Icons.checklist_rounded;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'key': key,
        'label': label,
        'targetHours': targetHours,
        'colorValue': colorValue,
        'iconCodePoint': iconCodePoint,
        'iconFontFamily': iconFontFamily,
        'isFlexible': isFlexible ? 1 : 0,
        'isDefault': isDefault ? 1 : 0,
        'sortOrder': sortOrder,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
      };

  factory MyDayCategoryOption.fromMap(Map<String, dynamic> map) => MyDayCategoryOption(
        id: map['id'],
        key: map['key'] ?? 'general',
        label: map['label'] ?? 'General Activity',
        targetHours: (map['targetHours'] as num?)?.toDouble() ?? 1.0,
        colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF0284C7,
        iconCodePoint: (map['iconCodePoint'] as num?)?.toInt() ?? Icons.checklist_rounded.codePoint,
        iconFontFamily: map['iconFontFamily'] ?? 'MaterialIcons',
        isFlexible: (map['isFlexible'] ?? 1) == 1,
        isDefault: (map['isDefault'] ?? 0) == 1,
        sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
        isActive: (map['isActive'] ?? 1) == 1,
        createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      );

  MyDayCategoryOption copyWith({
    String? label,
    double? targetHours,
    int? colorValue,
    int? iconCodePoint,
    bool? isFlexible,
    bool? isActive,
    int? sortOrder,
  }) {
    return MyDayCategoryOption(
      id: id,
      key: key,
      label: label ?? this.label,
      targetHours: targetHours ?? this.targetHours,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily,
      isFlexible: isFlexible ?? this.isFlexible,
      isDefault: isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}

/// Helper for categories and colors with dynamic fallback support
class MyDayCategoryHelper {
  static const Map<String, String> categoryLabels = {
    'cybersecurity': 'Cybersecurity Class',
    'work': 'Part-Time Work',
    'travel': 'Travel & Commute',
    'reading': 'Reading / Learning',
    'project': 'Project Development',
    'routine': 'Morning / Night Routine',
    'meals': 'Meals & Nutrition',
    'breaks': 'Breaks & Buffer',
    'entertainment': 'Entertainment',
    'relaxation': 'Relaxation',
    'sleep': 'Sleep',
    'general': 'General Activity',
  };

  static const Map<String, IconData> categoryIcons = {
    'cybersecurity': Icons.security_rounded,
    'work': Icons.work_outline_rounded,
    'travel': Icons.directions_car_rounded,
    'reading': Icons.menu_book_rounded,
    'project': Icons.terminal_rounded,
    'routine': Icons.wb_sunny_outlined,
    'meals': Icons.restaurant_rounded,
    'breaks': Icons.coffee_rounded,
    'entertainment': Icons.sports_esports_rounded,
    'relaxation': Icons.spa_rounded,
    'sleep': Icons.bedtime_outlined,
    'general': Icons.checklist_rounded,
  };

  static Color getCategoryColor(String category, {bool isDark = true}) {
    switch (category.toLowerCase().trim()) {
      case 'cybersecurity':
        return const Color(0xFF00F2FE); // Cyan / Blue glow
      case 'work':
        return const Color(0xFF38BDF8); // Sky Blue
      case 'travel':
        return const Color(0xFFF59E0B); // Amber Orange
      case 'reading':
        return const Color(0xFF10B981); // Emerald Green
      case 'project':
        return const Color(0xFF8B5CF6); // Electric Purple
      case 'routine':
        return const Color(0xFFF97316); // Bright Orange
      case 'meals':
        return const Color(0xFFEC4899); // Pink
      case 'breaks':
        return const Color(0xFF14B8A6); // Teal
      case 'entertainment':
        return const Color(0xFFE11D48); // Rose Red
      case 'relaxation':
        return const Color(0xFF6366F1); // Indigo
      case 'sleep':
        return const Color(0xFF475569); // Slate Indigo
      default:
        return const Color(0xFF0284C7);
    }
  }
}
