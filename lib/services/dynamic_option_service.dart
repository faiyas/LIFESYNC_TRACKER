import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'google_sheets_backup_service.dart';

class DynamicOptionService {
  static final DynamicOptionService instance = DynamicOptionService._init();
  final _uuid = const Uuid();

  DynamicOptionService._init();

  static const String typeExpenseCategory = 'expense_category';
  static const String typePaymentMethod = 'payment_method';
  static const String typeIncomeSource = 'income_source';
  static const String typeReminderCategory = 'reminder_category';
  static const String typeTodoCategory = 'todo_category';
  static const String typeBillCategory = 'bill_category';
  static const String typeDocumentCategory = 'document_category';
  static const String typeTripCategory = 'trip_category';
  static const String typeFoodCategory = 'food_category';
  static const String typeInventoryUnit = 'inventory_unit';

  static const Map<String, List<String>> _defaultOptions = {
    typeExpenseCategory: [
      'Food & Dining',
      'Shopping',
      'Housing',
      'Transportation',
      'Vehicle',
      'Entertainment',
      'Bills & Utilities',
      'Health & Fitness',
      'Travel',
      'Education',
      'Business',
      'Groceries',
      'Fuel',
      'Medical',
      'Personal Care',
      'Other',
    ],
    typePaymentMethod: [
      'Cash',
      'UPI',
      'Credit Card',
      'Debit Card',
      'Net Banking',
      'Wallet',
    ],
    typeIncomeSource: [
      'Salary',
      'Freelance',
      'Business',
      'Investments',
      'Rental',
      'Bonus',
      'Dividends',
      'Gift',
      'Other',
    ],
    typeReminderCategory: [
      'General',
      'Bills',
      'Health',
      'Work',
      'Personal',
      'Shopping',
      'Finance',
    ],
    typeTodoCategory: [
      'Work',
      'Personal',
      'Urgent',
      'Home',
      'Study',
      'Health',
      'Finance',
    ],
    typeBillCategory: [
      'Electricity',
      'Water',
      'Internet/WiFi',
      'Mobile Recharge',
      'Rent',
      'Gas',
      'Insurance',
      'Subscription',
      'Credit Card',
      'Maintenance',
      'Other',
    ],
    typeDocumentCategory: [
      'Identity/ID',
      'Tax/Financial',
      'Insurance',
      'Medical',
      'Vehicle',
      'Property',
      'Educational',
      'Employment',
      'Receipt/Invoice',
      'General',
    ],
    typeTripCategory: [
      'Vacation',
      'Business',
      'Weekend Getaway',
      'Road Trip',
      'International',
      'Family',
      'Solo',
    ],
    typeFoodCategory: [
      'Breakfast',
      'Lunch',
      'Dinner',
      'Snacks',
      'Beverages',
      'Dessert',
      'Supplements',
    ],
    typeInventoryUnit: [
      'pcs',
      'kg',
      'g',
      'l',
      'ml',
      'packets',
      'boxes',
      'meters',
      'pairs',
    ],
  };

  /// Ensure `app_options` and `expense_categories` tables exist and are seeded
  Future<void> _ensureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_options (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        isDefault INTEGER DEFAULT 0,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        isCustom INTEGER DEFAULT 0
      )
    ''');
  }

  /// Seeds default options for a specific type if currently empty
  Future<void> _seedDefaultsIfEmpty(Database db, String type) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM app_options WHERE type = ?', [type]),
    ) ?? 0;

    if (count == 0 && _defaultOptions.containsKey(type)) {
      final defaults = _defaultOptions[type]!;
      final batch = db.batch();
      final now = DateTime.now().toIso8601String();

      for (final name in defaults) {
        final optId = _uuid.v4();
        batch.insert('app_options', {
          'id': optId,
          'type': type,
          'name': name,
          'isDefault': 1,
          'createdAt': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        if (type == typeExpenseCategory) {
          batch.insert('expense_categories', {
            'id': optId,
            'name': name,
            'icon': 'category',
            'color': '0xFF0284C7',
            'isCustom': 0,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      await batch.commit(noResult: true);
    }
  }

  /// Retrieve 100% dynamic options for a specific type strictly from SQLite database
  Future<List<String>> getOptions(String type) async {
    final db = await AppDatabase.instance.database;
    await _ensureTable(db);
    await _seedDefaultsIfEmpty(db, type);

    final records = await db.query(
      'app_options',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'isDefault DESC, createdAt ASC, name ASC',
    );

    return records.map((e) => (e['name'] as String).trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Add a new dynamic option into database and sync with Google Sheets
  Future<bool> addOption(String type, String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return false;

    final db = await AppDatabase.instance.database;
    await _ensureTable(db);
    await _seedDefaultsIfEmpty(db, type);

    // Check if already exists (case-insensitive)
    final existing = await db.query(
      'app_options',
      where: 'type = ? AND LOWER(name) = ?',
      whereArgs: [type, cleanName.toLowerCase()],
    );

    if (existing.isNotEmpty) {
      return false; // Already exists
    }

    final newId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await db.insert('app_options', {
      'id': newId,
      'type': type,
      'name': cleanName,
      'isDefault': 0,
      'createdAt': now,
    });

    if (type == typeExpenseCategory) {
      await db.insert('expense_categories', {
        'id': newId,
        'name': cleanName,
        'icon': 'category',
        'color': '0xFF10B981',
        'isCustom': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    GoogleSheetsBackupService.instance.triggerDebouncedSync();
    return true;
  }

  /// Delete a dynamic option from database and sync with Google Sheets
  Future<void> deleteOption(String type, String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final db = await AppDatabase.instance.database;
    await _ensureTable(db);

    await db.delete(
      'app_options',
      where: 'type = ? AND LOWER(name) = ?',
      whereArgs: [type, cleanName.toLowerCase()],
    );

    if (type == typeExpenseCategory) {
      await db.delete(
        'expense_categories',
        where: 'LOWER(name) = ?',
        whereArgs: [cleanName.toLowerCase()],
      );
    }

    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  /// Clear all dynamic options for a specific type and sync with Google Sheets
  Future<void> clearOptions(String type) async {
    final db = await AppDatabase.instance.database;
    await _ensureTable(db);

    await db.delete('app_options', where: 'type = ?', whereArgs: [type]);

    if (type == typeExpenseCategory) {
      await db.delete('expense_categories');
    }

    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }
}

