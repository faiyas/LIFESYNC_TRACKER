import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Centralized Date/Time Service for LifeSync Tracker
///
/// Ensures the entire application uses the actual device local date, time, and timezone
/// as the single source of truth, with reactive minute-boundary ticks for live UI updates.
class AppTimeService extends ChangeNotifier {
  static final AppTimeService instance = AppTimeService._init();

  Timer? _minuteTicker;
  final StreamController<DateTime> _timeStreamController = StreamController<DateTime>.broadcast();
  DateTime _currentDateTime = DateTime.now();
  bool _isInitialized = false;

  AppTimeService._init() {
    _initTimezone();
    _startMinuteTicker();
  }

  /// Current real-time local device timestamp
  DateTime get now => DateTime.now();

  /// Cached timestamp updated on every minute boundary
  DateTime get currentDateTime => _currentDateTime;

  /// Stream of minute-by-minute time ticks
  Stream<DateTime> get timeStream => _timeStreamController.stream;

  /// Device timezone name (e.g., "IST", "EST", "UTC")
  String get timeZoneName => DateTime.now().timeZoneName;

  /// Device timezone offset (e.g. +05:30)
  Duration get timeZoneOffset => DateTime.now().timeZoneOffset;

  /// Format timezone offset as string (e.g. "+05:30")
  String get formattedTimeZoneOffset {
    final offset = timeZoneOffset;
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final sign = offset.isNegative ? '-' : '+';
    return '$sign$hours:$minutes';
  }

  /// Initialize and configure local timezone in `timezone` package
  void _initTimezone() {
    if (_isInitialized) return;
    try {
      tz.initializeTimeZones();
      final offset = DateTime.now().timeZoneOffset;
      final tzName = DateTime.now().timeZoneName;

      tz.Location? matchedLocation;
      try {
        for (final loc in tz.timeZoneDatabase.locations.values) {
          if (loc.currentTimeZone.offset == offset.inMilliseconds) {
            matchedLocation = loc;
            break;
          }
        }
      } catch (e) {
        debugPrint('Timezone location lookup error: $e');
      }

      if (matchedLocation != null) {
        tz.setLocalLocation(matchedLocation);
        debugPrint('AppTimeService: Timezone set to ${matchedLocation.name} (${offset.toString()})');
      } else {
        final customTz = tz.TimeZone(offset.inMilliseconds, isDst: false, abbreviation: tzName);
        final customLocation = tz.Location('DeviceLocal', [0], [0], [customTz]);
        tz.setLocalLocation(customLocation);
        debugPrint('AppTimeService: Timezone configured with custom offset $offset');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('AppTimeService: Failed to init timezone: $e');
    }
  }

  /// Starts a timer aligned with the start of the next minute
  void _startMinuteTicker() {
    _minuteTicker?.cancel();
    _currentDateTime = DateTime.now();

    final secondsUntilNextMinute = 60 - _currentDateTime.second;
    final msUntilNextMinute = (secondsUntilNextMinute * 1000) - _currentDateTime.millisecond;

    _minuteTicker = Timer(Duration(milliseconds: msUntilNextMinute > 0 ? msUntilNextMinute : 1000), () {
      _tick();
      _minuteTicker = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    });
  }

  void _tick() {
    _currentDateTime = DateTime.now();
    _timeStreamController.add(_currentDateTime);
    notifyListeners();
  }

  /// Pause or stop the background minute ticker
  void stopMinuteTicker() {
    _minuteTicker?.cancel();
    _minuteTicker = null;
  }

  /// Restart or resume the minute ticker
  void startMinuteTicker() {
    _startMinuteTicker();
  }

  /// Force a manual refresh (e.g. on app resume from background or timezone change)
  void refresh() {
    _initTimezone();
    _currentDateTime = DateTime.now();
    _timeStreamController.add(_currentDateTime);
    notifyListeners();
  }

  // ================= Formatting & Helper Utilities =================

  /// Context-aware greeting based on current local hour
  String get greeting {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    if (hour >= 17 && hour < 22) return 'Good Evening';
    return 'Good Night';
  }

  /// Formats time in "h:mm a" (e.g., "8:47 PM")
  String get formattedTime => DateFormat('h:mm a').format(now);

  /// Formats time in 24-hour format "HH:mm" (e.g., "20:47")
  String get formatted24HourTime => DateFormat('HH:mm').format(now);

  /// Formats date in "EEEE, d MMM" (e.g., "Wednesday, 26 Aug")
  String get formattedDate => DateFormat('EEEE, d MMM').format(now);

  /// Formats date in "yyyy-MM-dd" (e.g., "2026-08-26")
  String get todayDateString => DateFormat('yyyy-MM-dd').format(now);

  /// Minute of the day from 0 to 1439 (e.g., 8:47 PM = 20 * 60 + 47 = 1247)
  int get currentMinuteOfDay => now.hour * 60 + now.minute;

  /// Day progression fraction from 0.0 (midnight) to 1.0 (end of day)
  double get dayProgressPercent => (currentMinuteOfDay / 1440.0).clamp(0.0, 1.0);

  /// Minutes remaining until midnight
  int get minutesRemainingToday => (1440 - currentMinuteOfDay).clamp(0, 1440);

  /// Convert "HH:mm" string into minutes from midnight
  static int timeStringToMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return (h * 60 + m).clamp(0, 1439);
      }
    } catch (_) {}
    return 0;
  }

  /// Convert minutes from midnight (0..1439) into "HH:mm" (e.g. 527 -> "08:47")
  static String minutesToTimeString(int minutes) {
    final clamped = minutes.clamp(0, 1439);
    final h = (clamped ~/ 60).toString().padLeft(2, '0');
    final m = (clamped % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Convert minutes from midnight into human-readable 12-hour format (e.g. 527 -> "8:47 AM")
  static String minutesTo12HourString(int minutes) {
    final clamped = minutes.clamp(0, 1439);
    final h = clamped ~/ 60;
    final m = clamped % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = (h % 12 == 0) ? 12 : (h % 12);
    final minStr = m.toString().padLeft(2, '0');
    return '$hour12:$minStr $period';
  }

  /// Convert Duration into human readable string (e.g. 125 mins -> "2h 5m")
  static String formatDurationMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  /// Parses "HH:mm" string on a specific date into a local `DateTime`
  static DateTime parseTimeToDateTime(DateTime date, String timeStr) {
    final minutes = timeStringToMinutes(timeStr);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  @override
  void dispose() {
    _minuteTicker?.cancel();
    _timeStreamController.close();
    super.dispose();
  }
}
