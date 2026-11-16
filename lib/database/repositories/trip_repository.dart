import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../../models/models.dart';
import '../../services/google_sheets_backup_service.dart';

class TripRepository {
  TripRepository._();

  static Future<Database> get _db async => await AppDatabase.instance.database;

  // =================== TRIPS ===================

  static Future<List<TripPlanModel>> getAllTrips({String profileId = 'default_profile'}) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'trip_plans',
      where: 'profileId = ?',
      whereArgs: [profileId],
      orderBy: 'startDate ASC, createdAt DESC',
    );
    return maps.map((m) => TripPlanModel.fromMap(m)).toList();
  }

  static Future<TripPlanModel?> getTripById(String tripId) async {
    final db = await _db;
    final res = await db.query('trip_plans', where: 'id = ?', whereArgs: [tripId], limit: 1);
    if (res.isNotEmpty) {
      return TripPlanModel.fromMap(res.first);
    }
    return null;
  }

  static Future<void> insertTrip(TripPlanModel trip) async {
    final db = await _db;
    await db.insert(
      'trip_plans',
      trip.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<void> updateTrip(TripPlanModel trip) async {
    final db = await _db;
    await db.update(
      'trip_plans',
      trip.toMap(),
      where: 'id = ?',
      whereArgs: [trip.id],
    );
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<void> deleteTrip(String tripId) async {
    final db = await _db;
    await db.delete('trip_plans', where: 'id = ?', whereArgs: [tripId]);
    await db.delete('trip_expenses', where: 'tripId = ?', whereArgs: [tripId]);
    await db.delete('trip_locations', where: 'tripId = ?', whereArgs: [tripId]);
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  // =================== TRIP EXPENSES & BUDGET ===================

  static Future<List<TripExpense>> getTripExpenses(String tripId) async {
    final db = await _db;
    final maps = await db.query(
      'trip_expenses',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'date DESC, createdAt DESC',
    );
    return maps.map((m) => TripExpense.fromMap(m)).toList();
  }

  static Future<void> insertTripExpense(TripExpense expense) async {
    final db = await _db;
    await db.insert(
      'trip_expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<void> updateTripExpense(TripExpense expense) async {
    final db = await _db;
    await db.update(
      'trip_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<void> deleteTripExpense(String expenseId) async {
    final db = await _db;
    await db.delete('trip_expenses', where: 'id = ?', whereArgs: [expenseId]);
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<double> getTripTotalSpent(String tripId) async {
    final db = await _db;
    final res = await db.rawQuery(
      'SELECT SUM(amount) as total FROM trip_expenses WHERE tripId = ?',
      [tripId],
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // =================== TRIP LOCATIONS STORE ===================

  static Future<List<TripLocationItem>> getTripLocations(String tripId) async {
    final db = await _db;
    final maps = await db.query(
      'trip_locations',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'isVisited ASC, createdAt ASC',
    );
    return maps.map((m) => TripLocationItem.fromMap(m)).toList();
  }

  static Future<List<TripLocationItem>> getAllPlaces() async {
    final db = await _db;
    final maps = await db.query(
      'trip_locations',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => TripLocationItem.fromMap(m)).toList();
  }

  static Future<void> insertTripLocation(TripLocationItem location) async {
    final db = await _db;
    await db.insert(
      'trip_locations',
      location.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<void> updateTripLocation(TripLocationItem location) async {
    final db = await _db;
    await db.update(
      'trip_locations',
      location.toMap(),
      where: 'id = ?',
      whereArgs: [location.id],
    );
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<void> deleteTripLocation(String locationId) async {
    final db = await _db;
    await db.delete('trip_locations', where: 'id = ?', whereArgs: [locationId]);
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<void> toggleTripLocationVisited(String locationId, bool isVisited) async {
    final db = await _db;
    await db.update(
      'trip_locations',
      {'isVisited': isVisited ? 1 : 0},
      where: 'id = ?',
      whereArgs: [locationId],
    );
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  // =================== GLOBAL SAVED LOCATIONS ===================

  static Future<List<SavedLocation>> getSavedLocations({String profileId = 'default_profile'}) async {
    final db = await _db;
    final maps = await db.query(
      'saved_locations',
      where: 'profileId = ?',
      whereArgs: [profileId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => SavedLocation.fromMap(m)).toList();
  }

  static Future<void> insertSavedLocation(SavedLocation loc) async {
    final db = await _db;
    await db.insert('saved_locations', loc.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  static Future<void> deleteSavedLocation(String id) async {
    final db = await _db;
    await db.delete('saved_locations', where: 'id = ?', whereArgs: [id]);
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }
}
