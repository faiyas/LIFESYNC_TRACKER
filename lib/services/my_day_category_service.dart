import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/my_day_models.dart';
import 'google_sheets_backup_service.dart';

const _uuid = Uuid();

/// Database and local-cache CRUD service for My Day activity categories and keywords.
/// All categories, keywords, target hours, icons, and colors are retrieved dynamically
/// from SQLite (`my_day_category_options`) and cached in memory for zero-latency UI rendering.
class MyDayCategoryService extends ChangeNotifier {
  static final MyDayCategoryService instance = MyDayCategoryService._init();

  MyDayCategoryService._init();

  List<MyDayCategoryOption> _cachedCategories = [];
  bool _isInitialized = false;

  List<MyDayCategoryOption> get cachedCategories => List.unmodifiable(_cachedCategories);

  /// Ensure `my_day_category_options` table exists and has seeds in database
  Future<void> _ensureTableAndSeed(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS my_day_category_options (
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

    final existing = await db.query('my_day_category_options');
    if (existing.isEmpty) {
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
      for (final s in defaultSeeds) {
        batch.insert('my_day_category_options', s, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    }
  }

  // ================= READ (R) =================

  /// Retrieves all categories exclusively from SQLite database and updates local cache
  Future<List<MyDayCategoryOption>> getCategories({bool forceRefresh = false}) async {
    if (_isInitialized && !forceRefresh && _cachedCategories.isNotEmpty) {
      return _cachedCategories;
    }

    try {
      final db = await AppDatabase.instance.database;
      await _ensureTableAndSeed(db);

      final rows = await db.query(
        'my_day_category_options',
        where: 'isActive = 1',
        orderBy: 'sortOrder ASC, createdAt ASC',
      );

      _cachedCategories = rows.map((r) => MyDayCategoryOption.fromMap(r)).toList();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('MyDayCategoryService: Error reading categories from database: $e');
    }

    return _cachedCategories;
  }

  /// Get category option by key from database-populated cache
  MyDayCategoryOption? getCategoryByKey(String key) {
    final clean = key.toLowerCase().trim();
    for (final c in _cachedCategories) {
      if (c.key == clean) return c;
    }
    return null;
  }

  // ================= CREATE (C) =================

  /// Create a new category/keyword directly in SQLite database
  Future<MyDayCategoryOption?> addCategory({
    required String name,
    required double targetHours,
    required Color color,
    required IconData icon,
    bool isFlexible = true,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return null;

    final key = cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');

    final option = MyDayCategoryOption(
      id: _uuid.v4(),
      key: key,
      label: cleanName,
      targetHours: targetHours,
      colorValue: color.value,
      iconCodePoint: icon.codePoint,
      iconFontFamily: icon.fontFamily ?? 'MaterialIcons',
      isFlexible: isFlexible,
      isDefault: false,
      sortOrder: _cachedCategories.length,
      isActive: true,
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      final db = await AppDatabase.instance.database;
      await _ensureTableAndSeed(db);
      await db.insert('my_day_category_options', option.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      _cachedCategories.removeWhere((c) => c.key == key);
      _cachedCategories.add(option);
      notifyListeners();
      GoogleSheetsBackupService.instance.triggerDebouncedSync();
      return option;
    } catch (e) {
      debugPrint('MyDayCategoryService: Error adding category to database: $e');
      return null;
    }
  }

  // ================= UPDATE (U) =================

  /// Update an existing category in database & cache
  Future<bool> updateCategory(MyDayCategoryOption option) async {
    try {
      final db = await AppDatabase.instance.database;
      await _ensureTableAndSeed(db);
      await db.update(
        'my_day_category_options',
        option.toMap(),
        where: 'id = ?',
        whereArgs: [option.id],
      );

      final idx = _cachedCategories.indexWhere((c) => c.id == option.id);
      if (idx != -1) {
        _cachedCategories[idx] = option;
      }
      notifyListeners();
      GoogleSheetsBackupService.instance.triggerDebouncedSync();
      return true;
    } catch (e) {
      debugPrint('MyDayCategoryService: Error updating category in database: $e');
      return false;
    }
  }

  /// Update category fields by ID
  Future<bool> updateCategoryDetails({
    required String id,
    required String label,
    required double targetHours,
    required Color color,
    required IconData icon,
    bool isFlexible = true,
  }) async {
    final idx = _cachedCategories.indexWhere((c) => c.id == id);
    if (idx == -1) return false;

    final existing = _cachedCategories[idx];
    final updated = existing.copyWith(
      label: label.trim(),
      targetHours: targetHours,
      colorValue: color.value,
      iconCodePoint: icon.codePoint,
      isFlexible: isFlexible,
    );

    return await updateCategory(updated);
  }

  /// Batch update target hours for categories in SQLite database
  Future<void> saveBatchTargets(Map<String, double> targetsByKey) async {
    try {
      final db = await AppDatabase.instance.database;
      await _ensureTableAndSeed(db);

      final batch = db.batch();
      for (final entry in targetsByKey.entries) {
        batch.update(
          'my_day_category_options',
          {'targetHours': entry.value},
          where: 'key = ?',
          whereArgs: [entry.key],
        );
      }
      await batch.commit(noResult: true);

      for (var i = 0; i < _cachedCategories.length; i++) {
        final cat = _cachedCategories[i];
        if (targetsByKey.containsKey(cat.key)) {
          _cachedCategories[i] = cat.copyWith(targetHours: targetsByKey[cat.key]!);
        }
      }
      notifyListeners();
      GoogleSheetsBackupService.instance.triggerDebouncedSync();
    } catch (e) {
      debugPrint('MyDayCategoryService: Error batch saving targets to database: $e');
    }
  }

  // ================= DELETE (D) =================

  /// Delete a category by ID from SQLite database and remove from cache
  Future<bool> deleteCategory(String id) async {
    try {
      final db = await AppDatabase.instance.database;
      await _ensureTableAndSeed(db);
      await db.delete('my_day_category_options', where: 'id = ?', whereArgs: [id]);
      _cachedCategories.removeWhere((c) => c.id == id);
      notifyListeners();
      GoogleSheetsBackupService.instance.triggerDebouncedSync();
      return true;
    } catch (e) {
      debugPrint('MyDayCategoryService: Error deleting category from database: $e');
      return false;
    }
  }

  // ================= HELPERS =================

  /// Color lookup from database records in cache
  Color getCategoryColor(String key, {bool isDark = true}) {
    final clean = key.toLowerCase().trim();
    for (final c in _cachedCategories) {
      if (c.key == clean) return c.color;
    }
    return const Color(0xFF0284C7);
  }

  /// Icon lookup from database records in cache
  IconData getCategoryIcon(String key) {
    final clean = key.toLowerCase().trim();
    for (final c in _cachedCategories) {
      if (c.key == clean) return c.icon;
    }
    return Icons.checklist_rounded;
  }

  /// Label lookup from database records in cache
  String getCategoryLabel(String key) {
    final clean = key.toLowerCase().trim();
    for (final c in _cachedCategories) {
      if (c.key == clean) return c.label;
    }
    return clean;
  }
}
