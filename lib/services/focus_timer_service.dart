import 'dart:async';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/my_day_models.dart';
import 'google_sheets_backup_service.dart';

/// Service managing live focus sessions
class FocusTimerService extends ChangeNotifier {
  static final FocusTimerService instance = FocusTimerService._init();

  Timer? _timer;
  MyDayTask? _activeTask;
  String _taskTitle = 'General Focus Session';
  String _category = 'general';
  int _plannedMinutes = 25;
  int _elapsedSeconds = 0;
  int _pausedSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  DateTime? _startedAt;

  FocusTimerService._init();

  MyDayTask? get activeTask => _activeTask;
  String get taskTitle => _taskTitle;
  String get category => _category;
  int get plannedMinutes => _plannedMinutes;
  int get elapsedSeconds => _elapsedSeconds;
  int get remainingSeconds => ((_plannedMinutes * 60) - _elapsedSeconds).clamp(0, 99999);
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  bool get isOvertime => _elapsedSeconds > (_plannedMinutes * 60);

  double get progressFraction {
    final totalSec = _plannedMinutes * 60;
    if (totalSec <= 0) return 0.0;
    return (_elapsedSeconds / totalSec).clamp(0.0, 1.0);
  }

  String get formattedRemainingTime {
    final rem = remainingSeconds;
    final m = rem ~/ 60;
    final s = rem % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedElapsedTime {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void startFocus({
    MyDayTask? task,
    String? title,
    String? category,
    int? plannedMinutes,
  }) {
    _timer?.cancel();
    _activeTask = task;
    _taskTitle = title ?? task?.title ?? 'Deep Focus';
    _category = category ?? task?.category ?? 'general';
    _plannedMinutes = plannedMinutes ?? task?.durationMinutes ?? 25;
    _elapsedSeconds = 0;
    _pausedSeconds = 0;
    _isRunning = true;
    _isPaused = false;
    _startedAt = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        _elapsedSeconds++;
        notifyListeners();
      } else {
        _pausedSeconds++;
      }
    });

    notifyListeners();
  }

  void pause() {
    if (_isRunning && !_isPaused) {
      _isPaused = true;
      notifyListeners();
    }
  }

  void resume() {
    if (_isRunning && _isPaused) {
      _isPaused = false;
      notifyListeners();
    }
  }

  void addMinutes(int minutes) {
    _plannedMinutes += minutes;
    notifyListeners();
  }

  Future<FocusSessionLog?> finishAndSave({String? notes, bool markTaskCompleted = true}) async {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;

    final focusedMins = (_elapsedSeconds / 60).round();
    final pausedMins = (_pausedSeconds / 60).round();
    final endedAt = DateTime.now();

    final log = FocusSessionLog(
      taskId: _activeTask?.id,
      taskTitle: _taskTitle,
      category: _category,
      plannedMinutes: _plannedMinutes,
      focusedMinutes: focusedMins,
      pausedMinutes: pausedMins,
      startedAt: _startedAt?.toIso8601String() ?? endedAt.toIso8601String(),
      endedAt: endedAt.toIso8601String(),
      status: 'completed',
      notes: notes,
    );

    try {
      final db = await AppDatabase.instance.database;
      await db.insert('my_day_focus_sessions', log.toMap());

      if (_activeTask != null && markTaskCompleted) {
        await db.update(
          'my_day_tasks',
          {
            'isCompleted': 1,
            'actualDurationMinutes': focusedMins,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [_activeTask!.id],
        );
      }

      GoogleSheetsBackupService.instance.triggerDebouncedSync();
    } catch (e) {
      debugPrint('Error saving focus session: $e');
    }

    _activeTask = null;
    notifyListeners();
    return log;
  }

  void cancel() {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;
    _activeTask = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
