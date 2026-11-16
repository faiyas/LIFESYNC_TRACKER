import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lifesync_tracker/models/my_day_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (Database db, int version) async {
        // 1. my_day_category_options table
        await db.execute('''CREATE TABLE my_day_category_options (
          id TEXT PRIMARY KEY,
          key TEXT UNIQUE NOT NULL,
          label TEXT NOT NULL,
          targetHours REAL DEFAULT 1.0,
          colorValue INTEGER NOT NULL,
          iconCodePoint INTEGER NOT NULL,
          iconFontFamily TEXT DEFAULT 'MaterialIcons',
          isFlexible INTEGER DEFAULT 1,
          isDefault INTEGER DEFAULT 0,
          sortOrder INTEGER DEFAULT 0,
          isActive INTEGER DEFAULT 1,
          createdAt TEXT NOT NULL
        );''');

        // 2. my_day_preferences table
        await db.execute('''CREATE TABLE my_day_preferences (
          id TEXT PRIMARY KEY,
          profileId TEXT NOT NULL,
          wakeUpTime TEXT DEFAULT '08:00',
          bedTime TEXT DEFAULT '23:30',
          targetSleepHours REAL DEFAULT 8.0,
          targetWorkHours REAL DEFAULT 5.0,
          targetCyberHours REAL DEFAULT 2.0,
          targetReadingHours REAL DEFAULT 1.0,
          targetProjectHours REAL DEFAULT 1.5,
          targetEntertainmentHours REAL DEFAULT 1.0,
          bufferMinutesBetweenTasks INTEGER DEFAULT 10,
          isAutoAdjustEnabled INTEGER DEFAULT 1,
          updatedAt TEXT NOT NULL
        );''');

        // 3. my_day_tasks table
        await db.execute('''CREATE TABLE my_day_tasks (
          id TEXT PRIMARY KEY,
          profileId TEXT NOT NULL,
          title TEXT NOT NULL,
          category TEXT DEFAULT 'general',
          schedulingType TEXT DEFAULT 'flexible',
          date TEXT NOT NULL,
          startTime TEXT,
          endTime TEXT,
          durationMinutes INTEGER DEFAULT 30,
          priority TEXT DEFAULT 'medium',
          importanceScore INTEGER DEFAULT 5,
          isCompleted INTEGER DEFAULT 0,
          isMissed INTEGER DEFAULT 0,
          isPinned INTEGER DEFAULT 0,
          notes TEXT,
          recurrenceRule TEXT DEFAULT 'none',
          recurrenceDays TEXT,
          reminderBeforeMinutes INTEGER,
          reminderAtStart INTEGER DEFAULT 1,
          missedReminderShown INTEGER DEFAULT 0,
          actualDurationMinutes INTEGER,
          extraDataJson TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        );''');

        // 4. my_day_focus_sessions table
        await db.execute('''CREATE TABLE my_day_focus_sessions (
          id TEXT PRIMARY KEY,
          taskId TEXT,
          taskTitle TEXT NOT NULL,
          category TEXT DEFAULT 'general',
          plannedMinutes INTEGER NOT NULL,
          focusedMinutes INTEGER NOT NULL,
          pausedMinutes INTEGER DEFAULT 0,
          startedAt TEXT NOT NULL,
          endedAt TEXT NOT NULL,
          status TEXT DEFAULT 'completed',
          notes TEXT
        );''');

        // Seed initial default categories
        final now = DateTime.now().toIso8601String();
        final defaultSeeds = [
          {'id': 'cat_sleep', 'key': 'sleep', 'label': 'Target Sleep', 'targetHours': 8.0, 'colorValue': 0xFF6366F1, 'iconCodePoint': 0xe0e7, 'iconFontFamily': 'MaterialIcons', 'isFlexible': 0, 'isDefault': 1, 'sortOrder': 0, 'isActive': 1, 'createdAt': now},
          {'id': 'cat_work', 'key': 'work', 'label': 'Part-Time Job', 'targetHours': 5.0, 'colorValue': 0xFF38BDF8, 'iconCodePoint': 0xf02f3, 'iconFontFamily': 'MaterialIcons', 'isFlexible': 1, 'isDefault': 1, 'sortOrder': 1, 'isActive': 1, 'createdAt': now},
          {'id': 'cat_cybersecurity', 'key': 'cybersecurity', 'label': 'Cybersecurity Class / Study', 'targetHours': 2.0, 'colorValue': 0xFF00F2FE, 'iconCodePoint': 0xf013f, 'iconFontFamily': 'MaterialIcons', 'isFlexible': 1, 'isDefault': 1, 'sortOrder': 2, 'isActive': 1, 'createdAt': now},
          {'id': 'cat_project', 'key': 'project', 'label': 'Project Development', 'targetHours': 1.5, 'colorValue': 0xFF8B5CF6, 'iconCodePoint': 0xe62a, 'iconFontFamily': 'MaterialIcons', 'isFlexible': 1, 'isDefault': 1, 'sortOrder': 3, 'isActive': 1, 'createdAt': now},
          {'id': 'cat_reading', 'key': 'reading', 'label': 'Reading & Learning', 'targetHours': 1.0, 'colorValue': 0xFF10B981, 'iconCodePoint': 0xf001f, 'iconFontFamily': 'MaterialIcons', 'isFlexible': 1, 'isDefault': 1, 'sortOrder': 4, 'isActive': 1, 'createdAt': now},
          {'id': 'cat_entertainment', 'key': 'entertainment', 'label': 'Entertainment & Relaxation', 'targetHours': 1.0, 'colorValue': 0xFFEC4899, 'iconCodePoint': 0xf01ae, 'iconFontFamily': 'MaterialIcons', 'isFlexible': 1, 'isDefault': 1, 'sortOrder': 5, 'isActive': 1, 'createdAt': now},
          {'id': 'cat_travel', 'key': 'travel', 'label': 'Travel & Commute', 'targetHours': 1.0, 'colorValue': 0xFFF59E0B, 'iconCodePoint': 0xf06b4, 'iconFontFamily': 'MaterialIcons', 'isFlexible': 1, 'isDefault': 1, 'sortOrder': 6, 'isActive': 1, 'createdAt': now},
          {'id': 'cat_meals', 'key': 'meals', 'label': 'Meals & Nutrition', 'targetHours': 1.5, 'colorValue': 0xFFF97316, 'iconCodePoint': 0xf0118, 'iconFontFamily': 'MaterialIcons', 'isFlexible': 1, 'isDefault': 1, 'sortOrder': 7, 'isActive': 1, 'createdAt': now},
          {'id': 'cat_breaks', 'key': 'breaks', 'label': 'Breaks & Buffer', 'targetHours': 0.5, 'colorValue': 0xFF14B8A6, 'iconCodePoint': 0xf64f, 'iconFontFamily': 'MaterialIcons', 'isFlexible': 1, 'isDefault': 1, 'sortOrder': 8, 'isActive': 1, 'createdAt': now},
          {'id': 'cat_general', 'key': 'general', 'label': 'General Activity', 'targetHours': 0.5, 'colorValue': 0xFF0284C7, 'iconCodePoint': 0xf645, 'iconFontFamily': 'MaterialIcons', 'isFlexible': 1, 'isDefault': 1, 'sortOrder': 9, 'isActive': 1, 'createdAt': now},
        ];
        final batch = db.batch();
        for (final seed in defaultSeeds) {
          batch.insert('my_day_category_options', seed);
        }
        await batch.commit(noResult: true);
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('My Day Database CRUD Operations Verification', () {
    test('READ: Database seeds 10 default categories accurately', () async {
      final rows = await db.query('my_day_category_options', orderBy: 'sortOrder ASC');
      expect(rows.length, 10);
      expect(rows[0]['key'], 'sleep');
      expect(rows[0]['targetHours'], 8.0);
      expect(rows[1]['key'], 'work');
      expect(rows[1]['targetHours'], 5.0);
      expect(rows[2]['key'], 'cybersecurity');
      expect(rows[2]['targetHours'], 2.0);
    });

    test('CREATE: Adds a new custom category into the SQLite database', () async {
      final now = DateTime.now().toIso8601String();
      final custom = {
        'id': 'cat_fitness',
        'key': 'fitness',
        'label': 'Gym & Fitness',
        'targetHours': 1.5,
        'colorValue': 0xFF10B981,
        'iconCodePoint': Icons.fitness_center.codePoint,
        'iconFontFamily': 'MaterialIcons',
        'isFlexible': 1,
        'isDefault': 0,
        'sortOrder': 10,
        'isActive': 1,
        'createdAt': now,
      };

      await db.insert('my_day_category_options', custom);

      final rows = await db.query('my_day_category_options', where: 'id = ?', whereArgs: ['cat_fitness']);
      expect(rows.length, 1);
      expect(rows.first['label'], 'Gym & Fitness');
      expect(rows.first['targetHours'], 1.5);
      expect(rows.first['colorValue'], 0xFF10B981);
    });

    test('UPDATE: Modifies category label, target hours, and color in database', () async {
      // Update cybersecurity target from 2.0 to 3.0 and label
      final count = await db.update(
        'my_day_category_options',
        {
          'label': 'Advanced Cybersecurity & Labs',
          'targetHours': 3.0,
          'colorValue': 0xFF00E5FF,
        },
        where: 'key = ?',
        whereArgs: ['cybersecurity'],
      );

      expect(count, 1);

      final rows = await db.query('my_day_category_options', where: 'key = ?', whereArgs: ['cybersecurity']);
      expect(rows.first['label'], 'Advanced Cybersecurity & Labs');
      expect(rows.first['targetHours'], 3.0);
      expect(rows.first['colorValue'], 0xFF00E5FF);
    });

    test('UPDATE (Batch): Batch saves targets across multiple categories in database transaction', () async {
      final targetsToUpdate = {
        'sleep': 7.5,
        'work': 4.5,
        'project': 2.0,
      };

      final batch = db.batch();
      for (final entry in targetsToUpdate.entries) {
        batch.update(
          'my_day_category_options',
          {'targetHours': entry.value},
          where: 'key = ?',
          whereArgs: [entry.key],
        );
      }
      await batch.commit(noResult: true);

      final sleepRow = await db.query('my_day_category_options', where: 'key = ?', whereArgs: ['sleep']);
      expect(sleepRow.first['targetHours'], 7.5);

      final workRow = await db.query('my_day_category_options', where: 'key = ?', whereArgs: ['work']);
      expect(workRow.first['targetHours'], 4.5);

      final projectRow = await db.query('my_day_category_options', where: 'key = ?', whereArgs: ['project']);
      expect(projectRow.first['targetHours'], 2.0);
    });

    test('DELETE: Removes a category from the SQLite database', () async {
      // Add custom category first
      await db.insert('my_day_category_options', {
        'id': 'cat_temp',
        'key': 'temp_hobby',
        'label': 'Temporary Hobby',
        'targetHours': 1.0,
        'colorValue': 0xFF999999,
        'iconCodePoint': 0xe000,
        'iconFontFamily': 'MaterialIcons',
        'isFlexible': 1,
        'isDefault': 0,
        'sortOrder': 99,
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });

      var rows = await db.query('my_day_category_options', where: 'id = ?', whereArgs: ['cat_temp']);
      expect(rows.length, 1);

      // Delete
      final deleted = await db.delete('my_day_category_options', where: 'id = ?', whereArgs: ['cat_temp']);
      expect(deleted, 1);

      rows = await db.query('my_day_category_options', where: 'id = ?', whereArgs: ['cat_temp']);
      expect(rows.isEmpty, true);
    });

    test('TASKS CRUD: Inserts, reads, updates, and deletes tasks in SQLite', () async {
      final task = MyDayTask(
        id: 'task_cyber_101',
        profileId: 'default_profile',
        title: 'Network Pentesting Lab',
        category: 'cybersecurity',
        schedulingType: 'fixed',
        date: '2026-08-26',
        startTime: '18:00',
        endTime: '20:00',
        durationMinutes: 120,
        priority: 'high',
        extraDataJson: jsonEncode(CyberActivityDetails(
          topic: 'Burp Suite & SQL Injection',
          instructor: 'Dr. Smith',
          doubts: 'Review blind SQLi payloads',
        ).toMap()),
      );

      // Create
      await db.insert('my_day_tasks', task.toMap());

      // Read
      var taskRows = await db.query('my_day_tasks', where: 'id = ?', whereArgs: ['task_cyber_101']);
      expect(taskRows.length, 1);
      final retrieved = MyDayTask.fromMap(taskRows.first);
      expect(retrieved.title, 'Network Pentesting Lab');
      expect(retrieved.cyberDetails?.topic, 'Burp Suite & SQL Injection');

      // Update
      final updatedTask = retrieved.copyWith(
        isCompleted: true,
        actualDurationMinutes: 110,
        notes: 'Finished all lab modules on time',
      );
      await db.update('my_day_tasks', updatedTask.toMap(), where: 'id = ?', whereArgs: [updatedTask.id]);

      taskRows = await db.query('my_day_tasks', where: 'id = ?', whereArgs: ['task_cyber_101']);
      final updatedResult = MyDayTask.fromMap(taskRows.first);
      expect(updatedResult.isCompleted, true);
      expect(updatedResult.actualDurationMinutes, 110);
      expect(updatedResult.notes, 'Finished all lab modules on time');

      // Delete
      final deletedCount = await db.delete('my_day_tasks', where: 'id = ?', whereArgs: ['task_cyber_101']);
      expect(deletedCount, 1);
      taskRows = await db.query('my_day_tasks', where: 'id = ?', whereArgs: ['task_cyber_101']);
      expect(taskRows.isEmpty, true);
    });

    test('PREFERENCES CRUD: Inserts and updates daily preferences in SQLite', () async {
      final prefs = MyDayPreferences(
        id: 'pref_1',
        profileId: 'profile_test',
        wakeUpTime: '07:30',
        bedTime: '23:00',
        targetSleepHours: 8.5,
        targetWorkHours: 5.5,
        bufferMinutesBetweenTasks: 15,
      );

      await db.insert('my_day_preferences', prefs.toMap());

      var prefRows = await db.query('my_day_preferences', where: 'id = ?', whereArgs: ['pref_1']);
      expect(prefRows.length, 1);
      final retrieved = MyDayPreferences.fromMap(prefRows.first);
      expect(retrieved.wakeUpTime, '07:30');
      expect(retrieved.targetSleepHours, 8.5);
      expect(retrieved.bufferMinutesBetweenTasks, 15);

      // Update
      final updated = retrieved.copyWith(
        wakeUpTime: '08:00',
        targetSleepHours: 8.0,
      );
      await db.update('my_day_preferences', updated.toMap(), where: 'id = ?', whereArgs: ['pref_1']);

      prefRows = await db.query('my_day_preferences', where: 'id = ?', whereArgs: ['pref_1']);
      final updatedPref = MyDayPreferences.fromMap(prefRows.first);
      expect(updatedPref.wakeUpTime, '08:00');
      expect(updatedPref.targetSleepHours, 8.0);
    });
  });
}
