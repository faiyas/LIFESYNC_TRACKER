import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../features/health/data/database/initial_food_data.dart';

DatabaseFactory getSafeDatabaseFactory() {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }
  return databaseFactory;
}

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lifesync.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final factory = getSafeDatabaseFactory();
    final dbPath = await factory.getDatabasesPath();
    final path = join(dbPath, filePath);

    return await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: _createDB,
        onUpgrade: _onUpgradeDB,
        onOpen: _onOpenDB,
      ),
    );
  }

  Future<void> _onOpenDB(Database db) async {
    await _seedExpenseCategoriesIfEmpty(db);
  }

  Future<void> _seedExpenseCategoriesIfEmpty(Database db) async {
    try {
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM expense_categories'),
      ) ?? 0;
      if (count == 0) {
        final batch = db.batch();
        final defaultCats = [
          {'id': 'cat_food', 'name': 'Food & Dining', 'icon': 'restaurant', 'color': '0xFFF97316', 'isCustom': 0},
          {'id': 'cat_shopping', 'name': 'Shopping', 'icon': 'shopping_bag', 'color': '0xFFA855F7', 'isCustom': 0},
          {'id': 'cat_housing', 'name': 'Housing', 'icon': 'home', 'color': '0xFF3B82F6', 'isCustom': 0},
          {'id': 'cat_transport', 'name': 'Transportation', 'icon': 'directions_car', 'color': '0xFFEF4444', 'isCustom': 0},
          {'id': 'cat_vehicle', 'name': 'Vehicle', 'icon': 'build', 'color': '0xFFF59E0B', 'isCustom': 0},
          {'id': 'cat_entertainment', 'name': 'Entertainment', 'icon': 'movie', 'color': '0xFFEC4899', 'isCustom': 0},
          {'id': 'cat_bills', 'name': 'Bills & Utilities', 'icon': 'receipt', 'color': '0xFF14B8A6', 'isCustom': 0},
          {'id': 'cat_health', 'name': 'Health & Fitness', 'icon': 'fitness_center', 'color': '0xFF10B981', 'isCustom': 0},
          {'id': 'cat_travel', 'name': 'Travel', 'icon': 'flight', 'color': '0xFF6366F1', 'isCustom': 0},
          {'id': 'cat_education', 'name': 'Education', 'icon': 'school', 'color': '0xFFFB923C', 'isCustom': 0},
          {'id': 'cat_business', 'name': 'Business', 'icon': 'business_center', 'color': '0xFF06B6D4', 'isCustom': 0},
          {'id': 'cat_groceries', 'name': 'Groceries', 'icon': 'local_grocery_store', 'color': '0xFF84CC16', 'isCustom': 0},
          {'id': 'cat_fuel', 'name': 'Fuel', 'icon': 'local_gas_station', 'color': '0xFFE11D48', 'isCustom': 0},
          {'id': 'cat_other', 'name': 'Other', 'icon': 'category', 'color': '0xFF64748B', 'isCustom': 0},
        ];
        for (final cat in defaultCats) {
          batch.insert('expense_categories', cat, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await batch.commit(noResult: true);
      }
    } catch (_) {}
  }

  Future<void> _createDB(Database db, int version) async {
    await _executeV1Queries(db);
    await _executeV2Queries(db);
    await _executeV3Queries(db);
    await _executeV4Queries(db);
    await _executeV5Queries(db);
    await _executeV6Queries(db);
    await _executeV7Queries(db);
    await _executeV8Queries(db);

    await _seedExpenseCategoriesIfEmpty(db);

    // Default profile
    await db.insert('profiles', {
      'id': 'default_profile',
      'name': 'Main Profile',
      'isDefault': 1,
      'createdAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _executeV2Queries(db);
    }
    if (oldVersion < 3) {
      await _executeV3Queries(db);
    }
    if (oldVersion < 4) {
      await _executeV4Queries(db);
    }
    if (oldVersion < 5) {
      await _executeV5Queries(db);
    }
    if (oldVersion < 6) {
      await _executeV6Queries(db);
    }
    if (oldVersion < 7) {
      await _executeV7Queries(db);
    }
    if (oldVersion < 8) {
      await _executeV8Queries(db);
    }
  }

  Future<void> _executeV1Queries(Database db) async {
    final v1Queries = [
      '''CREATE TABLE IF NOT EXISTS profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        pin TEXT,
        recoveryQuestion TEXT,
        recoveryAnswer TEXT,
        isDefault INTEGER DEFAULT 0,
        createdAt TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        amount REAL NOT NULL,
        categoryId TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT,
        notes TEXT,
        tags TEXT,
        receiptUri TEXT,
        location TEXT,
        currency TEXT DEFAULT 'INR',
        isRecurring INTEGER DEFAULT 0,
        createdAt TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS expense_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        isCustom INTEGER DEFAULT 0
      );''',
      '''CREATE TABLE IF NOT EXISTS income (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        amount REAL NOT NULL,
        categoryId TEXT NOT NULL,
        source TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        date TEXT NOT NULL,
        isTaxRelevant INTEGER DEFAULT 0,
        isRecurring INTEGER DEFAULT 0,
        notes TEXT,
        createdAt TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS bills (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        dueDate TEXT NOT NULL,
        categoryId TEXT,
        fileUri TEXT,
        warrantyExpiry TEXT,
        isPaid INTEGER DEFAULT 0,
        notes TEXT,
        createdAt TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS todos (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        priority TEXT DEFAULT 'medium',
        category TEXT,
        dueDate TEXT,
        isCompleted INTEGER DEFAULT 0,
        isPinned INTEGER DEFAULT 0,
        isArchived INTEGER DEFAULT 0,
        isRecurring INTEGER DEFAULT 0,
        createdAt TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS subtasks (
        id TEXT PRIMARY KEY,
        todoId TEXT NOT NULL,
        title TEXT NOT NULL,
        isCompleted INTEGER DEFAULT 0
      );''',
      '''CREATE TABLE IF NOT EXISTS reminders (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        repeatType TEXT DEFAULT 'none',
        linkedEntityId TEXT,
        linkedEntityType TEXT,
        notes TEXT,
        createdAt TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        folder TEXT DEFAULT 'General',
        tags TEXT,
        isPinned INTEGER DEFAULT 0,
        isLocked INTEGER DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS habits (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        category TEXT,
        targetDaysPerWeek INTEGER DEFAULT 7,
        icon TEXT,
        color TEXT,
        reminderTime TEXT,
        createdAt TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS habit_logs (
        id TEXT PRIMARY KEY,
        habitId TEXT NOT NULL,
        date TEXT NOT NULL,
        status INTEGER DEFAULT 1
      );''',
      '''CREATE TABLE IF NOT EXISTS journal_entries (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        date TEXT NOT NULL,
        mood INTEGER NOT NULL,
        content TEXT NOT NULL,
        tags TEXT,
        imageUri TEXT,
        audioUri TEXT,
        createdAt TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS budgets (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        monthlyLimit REAL NOT NULL,
        monthYear TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS savings_goals (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        targetAmount REAL NOT NULL,
        currentAmount REAL DEFAULT 0,
        deadline TEXT,
        category TEXT,
        icon TEXT,
        createdAt TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS loans (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        principalAmount REAL NOT NULL,
        interestRate REAL NOT NULL,
        tenureMonths INTEGER NOT NULL,
        startDate TEXT NOT NULL,
        monthlyEmi REAL NOT NULL,
        notes TEXT,
        createdAt TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS subscriptions (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        name TEXT NOT NULL,
        cost REAL NOT NULL,
        billingCycle TEXT DEFAULT 'monthly',
        nextBillingDate TEXT NOT NULL,
        category TEXT,
        isPaused INTEGER DEFAULT 0,
        notes TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS vehicles (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        name TEXT NOT NULL,
        model TEXT,
        licensePlate TEXT,
        fuelType TEXT DEFAULT 'Petrol'
      );'''
    ];

    for (final q in v1Queries) {
      await db.execute(q);
    }
  }

  Future<void> _executeV2Queries(Database db) async {
    final v2Queries = [
      '''CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        name TEXT NOT NULL,
        mobile TEXT NOT NULL,
        altMobile TEXT,
        address TEXT,
        gpsLocation TEXT,
        photoUri TEXT,
        status TEXT DEFAULT 'active',
        notes TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS customer_jobs (
        id TEXT PRIMARY KEY,
        customerId TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT DEFAULT 'General',
        status TEXT DEFAULT 'pending',
        startDate TEXT NOT NULL,
        endDate TEXT,
        labourCost REAL DEFAULT 0.0,
        materialCost REAL DEFAULT 0.0,
        petrolCost REAL DEFAULT 0.0,
        miscCost REAL DEFAULT 0.0,
        advanceReceived REAL DEFAULT 0.0,
        pendingAmount REAL NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS borrowed_money (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        personName TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        interestRate REAL DEFAULT 0.0,
        dueDate TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        notes TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS pending_payments (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        customerId TEXT,
        invoiceNumber TEXT,
        totalAmount REAL NOT NULL,
        paidAmount REAL DEFAULT 0.0,
        remainingAmount REAL NOT NULL,
        dueDate TEXT NOT NULL,
        notes TEXT,
        status TEXT DEFAULT 'pending',
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        category TEXT DEFAULT 'General',
        title TEXT NOT NULL,
        filePath TEXT NOT NULL,
        fileType TEXT DEFAULT 'pdf',
        isPasswordProtected INTEGER DEFAULT 0,
        isFavorite INTEGER DEFAULT 0,
        notes TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS inventory (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT DEFAULT 'General',
        quantity INTEGER NOT NULL,
        unit TEXT DEFAULT 'pcs',
        purchasePrice REAL NOT NULL,
        sellingPrice REAL NOT NULL,
        supplier TEXT,
        stockAlertThreshold INTEGER DEFAULT 5,
        notes TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS inventory_transactions (
        id TEXT PRIMARY KEY,
        inventoryId TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        date TEXT NOT NULL,
        notes TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS reports_cache (
        id TEXT PRIMARY KEY,
        reportType TEXT NOT NULL,
        dateRange TEXT NOT NULL,
        cachedDataJson TEXT NOT NULL,
        generatedAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );'''
    ];

    for (final q in v2Queries) {
      await db.execute(q);
    }
  }

  Future<void> _executeV3Queries(Database db) async {
    final v3Queries = [
      '''CREATE TABLE IF NOT EXISTS investments (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        symbol TEXT,
        quantity REAL DEFAULT 1.0,
        buyPrice REAL NOT NULL,
        currentPrice REAL NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS insurances (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        provider TEXT NOT NULL,
        policyNumber TEXT,
        premiumAmount REAL NOT NULL,
        renewalDate TEXT NOT NULL,
        claimsHistory TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS tax_records (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        taxYear INTEGER NOT NULL,
        incomeTaxPaid REAL DEFAULT 0.0,
        gstPaid REAL DEFAULT 0.0,
        professionalTax REAL DEFAULT 0.0,
        deductions REAL DEFAULT 0.0,
        notes TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        company TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS sales_invoices (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        customerId TEXT NOT NULL,
        invoiceNumber TEXT NOT NULL,
        date TEXT NOT NULL,
        subtotal REAL NOT NULL,
        taxAmount REAL DEFAULT 0.0,
        discountAmount REAL DEFAULT 0.0,
        totalAmount REAL NOT NULL,
        paymentStatus TEXT DEFAULT 'pending',
        notes TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS purchase_orders (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        supplierId TEXT NOT NULL,
        orderNumber TEXT NOT NULL,
        date TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        status TEXT DEFAULT 'pending',
        notes TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS physical_assets (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        purchaseDate TEXT NOT NULL,
        purchaseValue REAL NOT NULL,
        currentValue REAL NOT NULL,
        depreciationRate REAL DEFAULT 0.0,
        notes TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS digital_vault (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        encryptedData TEXT NOT NULL,
        attachmentPath TEXT,
        isPinProtected INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS vehicle_logs (
        id TEXT PRIMARY KEY,
        vehicleId TEXT NOT NULL,
        logType TEXT NOT NULL,
        date TEXT NOT NULL,
        odometer REAL DEFAULT 0.0,
        cost REAL DEFAULT 0.0,
        details TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS trip_plans (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        budget REAL DEFAULT 0.0,
        checklistJson TEXT,
        itineraryJson TEXT,
        notes TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS group_expenses (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        groupName TEXT NOT NULL,
        membersJson TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        paidBy TEXT NOT NULL,
        splitType TEXT DEFAULT 'equal',
        splitDataJson TEXT,
        isSettled INTEGER DEFAULT 0
      );'''
    ];

    for (final q in v3Queries) {
      await db.execute(q);
    }
  }

  Future<void> _executeV4Queries(Database db) async {
    final v4Queries = [
      '''CREATE TABLE IF NOT EXISTS saved_locations (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        address TEXT NOT NULL,
        latitude REAL DEFAULT 0.0,
        longitude REAL DEFAULT 0.0,
        category TEXT DEFAULT 'Favorite',
        notes TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS offline_maps (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        regionName TEXT NOT NULL,
        centerLat REAL DEFAULT 37.7749,
        centerLng REAL DEFAULT -122.4194,
        zoomLevel INTEGER DEFAULT 12,
        sizeMb REAL DEFAULT 0.0,
        status TEXT DEFAULT 'downloaded',
        downloadedAt TEXT NOT NULL,
        fileUri TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS saved_trips (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        startLocation TEXT NOT NULL,
        endLocation TEXT NOT NULL,
        distanceKm REAL DEFAULT 0.0,
        durationMins INTEGER DEFAULT 0,
        mode TEXT DEFAULT 'driving',
        waypointsJson TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      );'''
    ];

    for (final q in v4Queries) {
      await db.execute(q);
    }
  }

  Future<void> _executeV5Queries(Database db) async {
    final v5Queries = [
      '''CREATE TABLE IF NOT EXISTS trip_plans (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        title TEXT NOT NULL,
        destination TEXT NOT NULL,
        destinationMapUrl TEXT,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        budget REAL DEFAULT 0.0,
        currency TEXT DEFAULT 'INR',
        status TEXT DEFAULT 'planned',
        coverCategory TEXT DEFAULT 'general',
        notes TEXT,
        checklistJson TEXT,
        itineraryJson TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS trip_expenses (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT DEFAULT 'Misc',
        date TEXT NOT NULL,
        paymentMethod TEXT DEFAULT 'UPI',
        location TEXT,
        mapUrl TEXT,
        notes TEXT,
        receiptUri TEXT,
        createdAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS trip_locations (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT DEFAULT 'Attraction',
        address TEXT,
        mapUrl TEXT,
        latitude REAL DEFAULT 0.0,
        longitude REAL DEFAULT 0.0,
        notes TEXT,
        estimatedCost REAL DEFAULT 0.0,
        isVisited INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL
      );'''
    ];

    for (final q in v5Queries) {
      await db.execute(q);
    }

    // Safely add missing columns to trip_plans if table already existed from V3
    try {
      await db.execute("ALTER TABLE trip_plans ADD COLUMN destination TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE trip_plans ADD COLUMN destinationMapUrl TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE trip_plans ADD COLUMN currency TEXT DEFAULT 'INR'");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE trip_plans ADD COLUMN status TEXT DEFAULT 'planned'");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE trip_plans ADD COLUMN coverCategory TEXT DEFAULT 'general'");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE trip_plans ADD COLUMN createdAt TEXT DEFAULT ''");
    } catch (_) {}
  }

  Future<void> _executeV6Queries(Database db) async {
    final v6Queries = [
      '''CREATE TABLE IF NOT EXISTS health_profile (
        id TEXT PRIMARY KEY,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
        heightCm REAL NOT NULL,
        weightKg REAL NOT NULL,
        activityLevel TEXT NOT NULL,
        goal TEXT NOT NULL,
        dailyCalorieTarget REAL NOT NULL,
        dailyStepGoal INTEGER NOT NULL,
        dailyWaterGoal INTEGER NOT NULL DEFAULT 2500,
        proteinTarget REAL NOT NULL,
        carbsTarget REAL NOT NULL,
        fatTarget REAL NOT NULL,
        fiberTarget REAL NOT NULL,
        createdAt TEXT,
        updatedAt TEXT
      );''',
      '''CREATE TABLE IF NOT EXISTS food_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        servingSize REAL NOT NULL,
        servingUnit TEXT NOT NULL,
        calories REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        fiber REAL NOT NULL,
        isCustom INTEGER DEFAULT 0,
        isFavorite INTEGER DEFAULT 0
      );''',
      '''CREATE TABLE IF NOT EXISTS food_logs (
        id TEXT PRIMARY KEY,
        foodId TEXT,
        foodName TEXT NOT NULL,
        mealType TEXT NOT NULL,
        quantity REAL NOT NULL,
        servingUnit TEXT NOT NULL,
        calories REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        fiber REAL NOT NULL,
        loggedAt TEXT NOT NULL,
        date TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS step_logs (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        steps INTEGER NOT NULL,
        source TEXT DEFAULT 'sensor',
        distanceKm REAL DEFAULT 0.0,
        activeMinutes INTEGER DEFAULT 0,
        estimatedCaloriesBurned REAL DEFAULT 0.0
      );''',
      '''CREATE TABLE IF NOT EXISTS water_logs (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        amountMl INTEGER NOT NULL,
        loggedAt TEXT NOT NULL
      );''',
      '''CREATE TABLE IF NOT EXISTS weight_logs (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        weightKg REAL NOT NULL,
        notes TEXT
      );'''
    ];

    for (final q in v6Queries) {
      await db.execute(q);
    }

    // Seed default health profile if not present
    final existingProfile = await db.query('health_profile', where: 'id = ?', whereArgs: ['default_health_profile']);
    if (existingProfile.isEmpty) {
      await db.insert('health_profile', {
        'id': 'default_health_profile',
        'age': 28,
        'gender': 'male',
        'heightCm': 175.0,
        'weightKg': 72.0,
        'activityLevel': 'moderately_active',
        'goal': 'maintain_weight',
        'dailyCalorieTarget': 2000.0,
        'dailyStepGoal': 10000,
        'dailyWaterGoal': 2500,
        'proteinTarget': 130.0,
        'carbsTarget': 220.0,
        'fatTarget': 65.0,
        'fiberTarget': 30.0,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    // Seed initial food database if empty
    final foodCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM food_items')) ?? 0;
    if (foodCount == 0) {
      final batch = db.batch();
      for (final item in InitialFoodData.initialFoods) {
        batch.insert('food_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<void> _executeV7Queries(Database db) async {
    // Ensure documents table exists
    await db.execute('''CREATE TABLE IF NOT EXISTS documents (
      id TEXT PRIMARY KEY,
      profileId TEXT NOT NULL,
      category TEXT DEFAULT 'General',
      title TEXT NOT NULL,
      filePath TEXT NOT NULL,
      fileType TEXT DEFAULT 'pdf',
      isPasswordProtected INTEGER DEFAULT 0,
      isFavorite INTEGER DEFAULT 0,
      notes TEXT,
      createdAt TEXT NOT NULL,
      extractedText TEXT,
      thumbnailPath TEXT,
      fileSize INTEGER,
      tags TEXT,
      updatedAt TEXT
    );''');

    // Safely add missing columns to documents if table already existed from earlier schema
    try {
      await db.execute("ALTER TABLE documents ADD COLUMN extractedText TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE documents ADD COLUMN thumbnailPath TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE documents ADD COLUMN fileSize INTEGER");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE documents ADD COLUMN tags TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE documents ADD COLUMN updatedAt TEXT");
    } catch (_) {}
  }

  Future<void> _executeV8Queries(Database db) async {
    // 1. My Day Routine Preferences
    await db.execute('''CREATE TABLE IF NOT EXISTS my_day_preferences (
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

    // 2. My Day Dynamic Tasks
    await db.execute('''CREATE TABLE IF NOT EXISTS my_day_tasks (
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

    // 3. Focus Session Logs
    await db.execute('''CREATE TABLE IF NOT EXISTS my_day_focus_sessions (
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

    // 4. Dynamic My Day Categories & Keywords Table
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

    // 5. Seed default categories directly in database
    final existingCategories = await db.query('my_day_category_options');
    if (existingCategories.isEmpty) {
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
        batch.insert('my_day_category_options', seed, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    }

    // Seed initial default preferences if not present
    final existingPrefs = await db.query('my_day_preferences', where: 'id = ?', whereArgs: ['default_my_day_prefs']);
    if (existingPrefs.isEmpty) {
      await db.insert('my_day_preferences', {
        'id': 'default_my_day_prefs',
        'profileId': 'default_profile',
        'wakeUpTime': '08:00',
        'bedTime': '23:30',
        'targetSleepHours': 8.0,
        'targetWorkHours': 5.0,
        'targetCyberHours': 2.0,
        'targetReadingHours': 1.0,
        'targetProjectHours': 1.5,
        'targetEntertainmentHours': 1.0,
        'bufferMinutesBetweenTasks': 10,
        'isAutoAdjustEnabled': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }
}
