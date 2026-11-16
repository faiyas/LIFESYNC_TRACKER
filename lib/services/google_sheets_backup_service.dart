import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/app_database.dart';

class GoogleSheetsBackupService {
  static final GoogleSheetsBackupService instance = GoogleSheetsBackupService._init();

  static const String _keyWebAppUrl = 'gsheets_webapp_url';
  static const String _keyAutoSync = 'gsheets_auto_sync_enabled';
  static const String _keyLastSync = 'gsheets_last_sync_time';

  Timer? _debounceTimer;
  bool _isSyncing = false;

  GoogleSheetsBackupService._init();

  bool get isSyncing => _isSyncing;

  Future<String?> getWebAppUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWebAppUrl);
  }

  Future<void> setWebAppUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_keyWebAppUrl);
    } else {
      await prefs.setString(_keyWebAppUrl, url.trim());
    }
  }

  Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoSync) ?? true;
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSync, enabled);
  }

  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastSync);
  }

  Future<void> _setLastSyncTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSync, time);
  }

  /// Extracts ALL local SQLite tables dynamically into a comprehensive payload map
  Future<Map<String, dynamic>> buildBackupPayload() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } catch (_) {}
    }

    final db = await AppDatabase.instance.database;
    final Map<String, dynamic> allTablesData = {};

    try {
      // Discover all user tables in SQLite database dynamically
      final tablesQuery = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
      );

      for (var row in tablesQuery) {
        final tableName = row['name'] as String?;
        if (tableName != null && tableName.isNotEmpty) {
          try {
            final records = await db.query(tableName);
            allTablesData[tableName] = records.map((r) => Map<String, dynamic>.from(r)).toList();
          } catch (e) {
            debugPrint('Error reading table $tableName for backup: $e');
            allTablesData[tableName] = [];
          }
        }
      }
    } catch (e) {
      debugPrint('Error querying sqlite_master: $e');
    }

    return {
      'action': 'sync_all',
      'timestamp': DateTime.now().toIso8601String(),
      'device': 'Flutter Offline First App',
      'totalTables': allTablesData.keys.length,
      'data': allTablesData,
    };
  }

  /// Triggers a debounced sync whenever local data changes
  void triggerDebouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 4), () async {
      final autoEnabled = await isAutoSyncEnabled();
      final url = await getWebAppUrl();
      if (autoEnabled && url != null && url.isNotEmpty) {
        debugPrint('GoogleSheets: Auto-sync triggered after data change');
        await backupNow(isAutoSync: true);
      }
    });
  }

  /// Perform instant cloud backup (Upload) to Google Sheets
  Future<Map<String, dynamic>> backupNow({bool isAutoSync = false}) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } catch (_) {}
    }

    final url = await getWebAppUrl();
    if (url == null || url.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Google Apps Script Web App URL is not configured in Settings.',
      };
    }

    if (_isSyncing) {
      return {
        'success': false,
        'message': 'A sync operation is already in progress.',
      };
    }

    _isSyncing = true;

    try {
      final payload = await buildBackupPayload();
      final uri = Uri.parse(url.trim());

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 45));

      _isSyncing = false;

      if (response.statusCode == 200 || response.statusCode == 302) {
        final nowStr = DateTime.now().toIso8601String();
        await _setLastSyncTime(nowStr);

        return {
          'success': true,
          'message': 'Successfully backed up all tables & data to Google Sheets!',
          'syncedAt': nowStr,
        };
      } else {
        return {
          'success': false,
          'message': 'Server responded with HTTP ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      _isSyncing = false;
      debugPrint('GoogleSheets backup error: $e');
      return {
        'success': false,
        'message': 'Google Sheets sync failed: $e',
      };
    }
  }

  /// 2-Way Restore: Pulls all sheet tables from Google Sheets and merges them into SQLite
  Future<Map<String, dynamic>> restoreFromCloud() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } catch (_) {}
    }

    final url = await getWebAppUrl();
    if (url == null || url.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Google Apps Script Web App URL is not configured in Settings.',
      };
    }

    if (_isSyncing) {
      return {
        'success': false,
        'message': 'A sync operation is already in progress.',
      };
    }

    _isSyncing = true;

    try {
      var fetchUri = Uri.parse(url.trim());
      if (!fetchUri.queryParameters.containsKey('action')) {
        final queryParams = Map<String, String>.from(fetchUri.queryParameters);
        queryParams['action'] = 'restore';
        fetchUri = fetchUri.replace(queryParameters: queryParams);
      }

      final response = await http.get(fetchUri).timeout(const Duration(seconds: 45));
      _isSyncing = false;

      if (response.statusCode == 200 || response.statusCode == 302) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map || decoded['data'] is! Map) {
          return {
            'success': false,
            'message': 'Invalid data format received from Google Sheets restore endpoint.',
          };
        }

        final Map<String, dynamic> allData = Map<String, dynamic>.from(decoded['data']);
        final db = await AppDatabase.instance.database;

        int totalRestoredTables = 0;
        int totalRestoredRecords = 0;

        // Query existing SQLite tables to ensure safe insertion
        final tablesQuery = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
        );
        final existingTableNames = tablesQuery.map((r) => (r['name'] as String).toLowerCase()).toSet();

        for (final entry in allData.entries) {
          final tableName = entry.key.toLowerCase();
          final rawRows = entry.value;

          if (rawRows is List && existingTableNames.contains(tableName)) {
            final actualTableNameQuery = tablesQuery.firstWhere(
              (r) => (r['name'] as String).toLowerCase() == tableName,
            );
            final actualTableName = actualTableNameQuery['name'] as String;

            for (final row in rawRows) {
              if (row is Map) {
                final safeRow = Map<String, dynamic>.from(row);
                try {
                  await db.insert(
                    actualTableName,
                    safeRow,
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                  totalRestoredRecords++;
                } catch (e) {
                  debugPrint('Error inserting row into $actualTableName: $e');
                }
              }
            }
            totalRestoredTables++;
          }
        }

        final nowStr = DateTime.now().toIso8601String();
        await _setLastSyncTime(nowStr);

        return {
          'success': true,
          'message': 'Successfully restored $totalRestoredRecords records across $totalRestoredTables tables from Google Sheets!',
          'totalTables': totalRestoredTables,
          'totalRecords': totalRestoredRecords,
          'syncedAt': nowStr,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to pull cloud backup. HTTP ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      _isSyncing = false;
      debugPrint('GoogleSheets restore error: $e');
      return {
        'success': false,
        'message': 'Cloud restore failed: $e',
      };
    }
  }

  /// Test connectivity to the provided or saved Google Apps Script Web App URL
  Future<Map<String, dynamic>> testConnection([String? testUrl]) async {
    final url = testUrl ?? await getWebAppUrl();
    if (url == null || url.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Please enter a Google Apps Script Web App URL.',
      };
    }

    try {
      final uri = Uri.parse(url.trim());
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 302) {
        return {
          'success': true,
          'message': 'Connection successful! Google Apps Script Web App is online and ready.',
        };
      } else {
        return {
          'success': false,
          'message': 'Server reached but returned HTTP ${response.statusCode}. Check Web App deployment access ("Anyone").',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection failed: $e',
      };
    }
  }
}
