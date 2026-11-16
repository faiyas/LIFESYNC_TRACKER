import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync_tracker/models/my_day_models.dart';
import 'package:lifesync_tracker/services/app_time_service.dart';
import 'package:lifesync_tracker/services/dynamic_scheduling_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DynamicSchedulingEngine & AppTimeService Tests', () {
    test('AppTimeService time conversion helpers work accurately', () {
      expect(AppTimeService.timeStringToMinutes('08:00'), 480);
      expect(AppTimeService.timeStringToMinutes('20:47'), 1247);
      expect(AppTimeService.minutesToTimeString(480), '08:00');
      expect(AppTimeService.minutesTo12HourString(480), '8:00 AM');
      expect(AppTimeService.minutesTo12HourString(1247), '8:47 PM');
      expect(AppTimeService.formatDurationMinutes(125), '2h 5m');
      expect(AppTimeService.formatDurationMinutes(60), '1h');
      expect(AppTimeService.formatDurationMinutes(45), '45m');
    });

    test('DynamicSchedulingEngine anchors fixed tasks and fits flexible tasks in gaps', () {
      final engine = DynamicSchedulingEngine.instance;
      final testDate = DateTime(2026, 8, 26);
      final preferences = MyDayPreferences(
        profileId: 'test_profile',
        wakeUpTime: '08:00',
        bedTime: '23:00',
        targetSleepHours: 8.0,
        targetWorkHours: 4.0,
        targetCyberHours: 2.0,
        bufferMinutesBetweenTasks: 10,
      );

      final tasks = [
        // Fixed Cybersecurity Class: 6:00 PM (18:00) to 8:00 PM (20:00)
        MyDayTask(
          id: 'task-cyber-class',
          profileId: 'test_profile',
          title: 'Cybersecurity Class',
          category: 'cybersecurity',
          schedulingType: 'fixed',
          date: '2026-08-26',
          startTime: '18:00',
          endTime: '20:00',
          durationMinutes: 120,
          priority: 'high',
        ),
        // Fixed Work shift: 10:00 AM (10:00) to 2:00 PM (14:00)
        MyDayTask(
          id: 'task-work',
          profileId: 'test_profile',
          title: 'Part-Time Work',
          category: 'work',
          schedulingType: 'fixed',
          date: '2026-08-26',
          startTime: '10:00',
          endTime: '14:00',
          durationMinutes: 240,
          priority: 'high',
        ),
        // Flexible Project Work: 90 mins
        MyDayTask(
          id: 'task-project',
          profileId: 'test_profile',
          title: 'Project Development',
          category: 'project',
          schedulingType: 'flexible',
          date: '2026-08-26',
          durationMinutes: 90,
          priority: 'high',
          importanceScore: 9,
        ),
        // Flexible Reading: 45 mins
        MyDayTask(
          id: 'task-reading',
          profileId: 'test_profile',
          title: 'Cyber Reading / Command Practice',
          category: 'reading',
          schedulingType: 'flexible',
          date: '2026-08-26',
          durationMinutes: 45,
          priority: 'medium',
          importanceScore: 7,
        ),
      ];

      // Compute schedule for morning device time 08:30
      final result = engine.computeSchedule(
        date: testDate,
        allTasks: tasks,
        preferences: preferences,
        deviceTime: DateTime(2026, 8, 26, 8, 30),
      );

      // Verify slots are scheduled
      expect(result.slots.isNotEmpty, true);
      expect(result.slots.length, 4);

      // Verify Fixed tasks maintain exact time bounds
      final workSlot = result.slots.firstWhere((s) => s.task.id == 'task-work');
      expect(workSlot.isFixed, true);
      expect(workSlot.startMinute, 600); // 10:00 AM
      expect(workSlot.endMinute, 840); // 2:00 PM

      final cyberSlot = result.slots.firstWhere((s) => s.task.id == 'task-cyber-class');
      expect(cyberSlot.isFixed, true);
      expect(cyberSlot.startMinute, 1080); // 6:00 PM
      expect(cyberSlot.endMinute, 1200); // 8:00 PM

      // Verify Flexible tasks were placed in open gaps without collision
      final projectSlot = result.slots.firstWhere((s) => s.task.id == 'task-project');
      expect(projectSlot.isFixed, false);
      // Project (90 mins) should be placed in the morning gap (8:00 AM - 10:00 AM = 120 mins)
      expect(projectSlot.startMinute >= 480, true);
      expect(projectSlot.endMinute <= 600, true);

      // Verify Reading (45 mins) is placed in afternoon gap (2:00 PM - 6:00 PM = 240 mins)
      final readingSlot = result.slots.firstWhere((s) => s.task.id == 'task-reading');
      expect(readingSlot.startMinute >= 840, true);

      // Verify category summaries
      expect(result.categorySummaries.containsKey('cybersecurity'), true);
      expect(result.categorySummaries.containsKey('work'), true);
      expect(result.categorySummaries.containsKey('project'), true);
      expect(result.categorySummaries.containsKey('reading'), true);

      // Verify available flexible time is positive and calculated
      expect(result.availableFlexibleMinutes > 0, true);
    });

    test('Dynamic shift occurs when fixed task start time changes', () {
      final engine = DynamicSchedulingEngine.instance;
      final testDate = DateTime(2026, 8, 26);
      final preferences = MyDayPreferences(
        profileId: 'test_profile',
        wakeUpTime: '08:00',
        bedTime: '23:00',
      );

      // Class moved from 6 PM to 7 PM
      final tasks = [
        MyDayTask(
          id: 'task-cyber-class',
          profileId: 'test_profile',
          title: 'Cybersecurity Class',
          category: 'cybersecurity',
          schedulingType: 'fixed',
          date: '2026-08-26',
          startTime: '19:00', // 7 PM
          endTime: '21:00', // 9 PM
          durationMinutes: 120,
        ),
        MyDayTask(
          id: 'task-evening-study',
          profileId: 'test_profile',
          title: 'Evening Study',
          category: 'reading',
          schedulingType: 'flexible',
          date: '2026-08-26',
          durationMinutes: 60,
        ),
      ];

      final result = engine.computeSchedule(
        date: testDate,
        allTasks: tasks,
        preferences: preferences,
      );

      expect(result.slots.length, 2);
      final classSlot = result.slots.firstWhere((s) => s.task.id == 'task-cyber-class');
      expect(classSlot.startMinute, 1140); // 7:00 PM
    });

    test('MyDayCategoryOption serializes and deserializes accurately with color and icon', () {
      final opt = MyDayCategoryOption(
        id: 'cat_gym',
        key: 'gym',
        label: 'Gym & Fitness',
        targetHours: 1.5,
        colorValue: 0xFF10B981,
        iconCodePoint: 0xe28d,
        isFlexible: true,
      );

      final map = opt.toMap();
      expect(map['key'], 'gym');
      expect(map['label'], 'Gym & Fitness');
      expect(map['targetHours'], 1.5);
      expect(map['colorValue'], 0xFF10B981);

      final restored = MyDayCategoryOption.fromMap(map);
      expect(restored.id, 'cat_gym');
      expect(restored.key, 'gym');
      expect(restored.label, 'Gym & Fitness');
      expect(restored.targetHours, 1.5);
      expect(restored.color.value, 0xFF10B981);
    });

    test('Recurring tasks support date-specific completion without affecting future dates', () {
      final recurringTask = MyDayTask(
        id: 'task-daily-standup',
        profileId: 'test_profile',
        title: 'Daily Morning Standup',
        category: 'work',
        schedulingType: 'fixed',
        date: '2026-08-26',
        startTime: '09:00',
        endTime: '09:30',
        durationMinutes: 30,
        recurrenceRule: 'daily',
        extraDataJson: '{"completedDates":["2026-08-26"]}',
      );

      // Verify completion for 2026-08-26 is true
      expect(recurringTask.isCompletedForDate('2026-08-26'), true);

      // Verify completion for 2026-08-27 is false
      expect(recurringTask.isCompletedForDate('2026-08-27'), false);

      final engine = DynamicSchedulingEngine.instance;
      final preferences = MyDayPreferences(profileId: 'test_profile');

      // Schedule for Aug 26 -> isCompleted should be true
      final resAug26 = engine.computeSchedule(
        date: DateTime(2026, 8, 26),
        allTasks: [recurringTask],
        preferences: preferences,
      );
      expect(resAug26.slots.first.isCompleted, true);

      // Schedule for Aug 27 -> isCompleted should be false
      final resAug27 = engine.computeSchedule(
        date: DateTime(2026, 8, 27),
        allTasks: [recurringTask],
        preferences: preferences,
      );
      expect(resAug27.slots.first.isCompleted, false);
    });
  });
}
