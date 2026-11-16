import 'package:sqflite/sqflite.dart';
import '../../../../database/app_database.dart';
import '../../../../services/google_sheets_backup_service.dart';
import '../models/health_models.dart';

class HealthRepository {
  // ==================== HEALTH PROFILE ====================

  static Future<HealthProfile> getHealthProfile() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('health_profile', where: 'id = ?', whereArgs: ['default_health_profile']);
    if (maps.isNotEmpty) {
      return HealthProfile.fromMap(maps.first);
    }
    final defaultProfile = HealthProfile();
    await db.insert('health_profile', defaultProfile.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return defaultProfile;
  }

  static Future<void> saveHealthProfile(HealthProfile profile) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'health_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  // ==================== FOOD ITEMS & DATABASE ====================

  static Future<List<FoodItem>> getAllFoods() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('food_items', orderBy: 'isFavorite DESC, name ASC');
    return maps.map((m) => FoodItem.fromMap(m)).toList();
  }

  static Future<List<FoodItem>> searchFoods(String query, {String? category}) async {
    final db = await AppDatabase.instance.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (query.isNotEmpty && category != null && category != 'All') {
      whereClause = 'name LIKE ? AND category = ?';
      whereArgs = ['%$query%', category];
    } else if (query.isNotEmpty) {
      whereClause = 'name LIKE ?';
      whereArgs = ['%$query%'];
    } else if (category != null && category != 'All') {
      whereClause = 'category = ?';
      whereArgs = [category];
    }

    final maps = await db.query(
      'food_items',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'isFavorite DESC, name ASC',
    );
    return maps.map((m) => FoodItem.fromMap(m)).toList();
  }

  static Future<List<FoodItem>> getFavoriteFoods() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('food_items', where: 'isFavorite = 1', orderBy: 'name ASC');
    return maps.map((m) => FoodItem.fromMap(m)).toList();
  }

  static Future<List<FoodItem>> getRecentFoods({int limit = 10}) async {
    final db = await AppDatabase.instance.database;
    final query = '''
      SELECT DISTINCT f.* FROM food_items f
      JOIN food_logs l ON f.id = l.foodId
      ORDER BY l.loggedAt DESC
      LIMIT ?
    ''';
    final maps = await db.rawQuery(query, [limit]);
    return maps.map((m) => FoodItem.fromMap(m)).toList();
  }

  static Future<void> toggleFavoriteFood(String foodId, bool isFavorite) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'food_items',
      {'isFavorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [foodId],
    );
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<void> insertCustomFood(FoodItem food) async {
    final db = await AppDatabase.instance.database;
    await db.insert('food_items', food.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<void> deleteCustomFood(String foodId) async {
    final db = await AppDatabase.instance.database;
    await db.delete('food_items', where: 'id = ? AND isCustom = 1', whereArgs: [foodId]);
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  // ==================== FOOD LOGS ====================

  static Future<List<FoodLog>> getFoodLogsByDate(String date) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'food_logs',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'loggedAt ASC',
    );
    return maps.map((m) => FoodLog.fromMap(m)).toList();
  }

  static Future<List<FoodLog>> getFoodLogsByRange(String startDate, String endDate) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'food_logs',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC, loggedAt ASC',
    );
    return maps.map((m) => FoodLog.fromMap(m)).toList();
  }

  static Future<void> insertFoodLog(FoodLog log) async {
    final db = await AppDatabase.instance.database;
    await db.insert('food_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<void> updateFoodLog(FoodLog log) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'food_logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<void> deleteFoodLog(String logId) async {
    final db = await AppDatabase.instance.database;
    await db.delete('food_logs', where: 'id = ?', whereArgs: [logId]);
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  // ==================== STEP LOGS ====================

  static Future<StepLog?> getStepLogByDate(String date) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('step_logs', where: 'date = ?', whereArgs: [date]);
    if (maps.isNotEmpty) {
      return StepLog.fromMap(maps.first);
    }
    return null;
  }

  static Future<void> saveStepLog(StepLog log) async {
    final db = await AppDatabase.instance.database;
    await db.insert('step_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<List<StepLog>> getStepLogsByRange(String startDate, String endDate) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'step_logs',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC',
    );
    return maps.map((m) => StepLog.fromMap(m)).toList();
  }

  // ==================== WATER LOGS ====================

  static Future<List<WaterLog>> getWaterLogsByDate(String date) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('water_logs', where: 'date = ?', whereArgs: [date], orderBy: 'loggedAt ASC');
    return maps.map((m) => WaterLog.fromMap(m)).toList();
  }

  static Future<int> getTodayWaterTotal(String date) async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT SUM(amountMl) as total FROM water_logs WHERE date = ?', [date]);
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  static Future<void> insertWaterLog(WaterLog log) async {
    final db = await AppDatabase.instance.database;
    await db.insert('water_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<bool> deleteLatestWaterLog(String date) async {
    final db = await AppDatabase.instance.database;
    final latest = await db.query(
      'water_logs',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'loggedAt DESC',
      limit: 1,
    );
    if (latest.isNotEmpty) {
      final id = latest.first['id'] as String;
      await db.delete('water_logs', where: 'id = ?', whereArgs: [id]);
      GoogleSheetsBackupService.instance.triggerDebouncedSync();
      return true;
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>> getWaterAggregatesByRange(String startDate, String endDate) async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('''
      SELECT date, SUM(amountMl) as totalMl
      FROM water_logs
      WHERE date >= ? AND date <= ?
      GROUP BY date
      ORDER BY date ASC
    ''', [startDate, endDate]);
    return result;
  }

  // ==================== WEIGHT LOGS ====================

  static Future<List<WeightLog>> getAllWeightLogs() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('weight_logs', orderBy: 'date ASC');
    return maps.map((m) => WeightLog.fromMap(m)).toList();
  }

  static Future<WeightLog?> getLatestWeight() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('weight_logs', orderBy: 'date DESC', limit: 1);
    if (maps.isNotEmpty) {
      return WeightLog.fromMap(maps.first);
    }
    return null;
  }

  static Future<void> saveWeightLog(WeightLog log) async {
    final db = await AppDatabase.instance.database;
    await db.insert('weight_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    // Also update health profile's weightKg
    await db.update(
      'health_profile',
      {'weightKg': log.weightKg, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: ['default_health_profile'],
    );
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<void> deleteWeightLog(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('weight_logs', where: 'id = ?', whereArgs: [id]);
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }
}
