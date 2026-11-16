import 'package:uuid/uuid.dart';

class HealthProfile {
  final String id;
  final int age;
  final String gender; // 'male', 'female', 'other'
  final double heightCm;
  final double weightKg;
  final String activityLevel; // 'sedentary', 'lightly_active', 'moderately_active', 'very_active'
  final String goal; // 'lose_weight', 'maintain_weight', 'gain_weight'
  final double dailyCalorieTarget;
  final int dailyStepGoal;
  final int dailyWaterGoal; // in ml
  final double proteinTarget; // in grams
  final double carbsTarget; // in grams
  final double fatTarget; // in grams
  final double fiberTarget; // in grams
  final String createdAt;
  final String updatedAt;

  HealthProfile({
    String? id,
    this.age = 28,
    this.gender = 'male',
    this.heightCm = 175.0,
    this.weightKg = 72.0,
    this.activityLevel = 'moderately_active',
    this.goal = 'maintain_weight',
    this.dailyCalorieTarget = 2000.0,
    this.dailyStepGoal = 10000,
    this.dailyWaterGoal = 2500,
    this.proteinTarget = 130.0,
    this.carbsTarget = 220.0,
    this.fatTarget = 65.0,
    this.fiberTarget = 30.0,
    String? createdAt,
    String? updatedAt,
  })  : id = id ?? 'default_health_profile',
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  HealthProfile copyWith({
    String? id,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? activityLevel,
    String? goal,
    double? dailyCalorieTarget,
    int? dailyStepGoal,
    int dailyWaterGoal = 2500,
    double? proteinTarget,
    double? carbsTarget,
    double? fatTarget,
    double? fiberTarget,
    String? createdAt,
    String? updatedAt,
  }) {
    return HealthProfile(
      id: id ?? this.id,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      dailyWaterGoal: dailyWaterGoal,
      proteinTarget: proteinTarget ?? this.proteinTarget,
      carbsTarget: carbsTarget ?? this.carbsTarget,
      fatTarget: fatTarget ?? this.fatTarget,
      fiberTarget: fiberTarget ?? this.fiberTarget,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'age': age,
      'gender': gender,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'activityLevel': activityLevel,
      'goal': goal,
      'dailyCalorieTarget': dailyCalorieTarget,
      'dailyStepGoal': dailyStepGoal,
      'dailyWaterGoal': dailyWaterGoal,
      'proteinTarget': proteinTarget,
      'carbsTarget': carbsTarget,
      'fatTarget': fatTarget,
      'fiberTarget': fiberTarget,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory HealthProfile.fromMap(Map<String, dynamic> map) {
    return HealthProfile(
      id: map['id'] as String? ?? 'default_health_profile',
      age: (map['age'] as num?)?.toInt() ?? 28,
      gender: map['gender'] as String? ?? 'male',
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 175.0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 72.0,
      activityLevel: map['activityLevel'] as String? ?? 'moderately_active',
      goal: map['goal'] as String? ?? 'maintain_weight',
      dailyCalorieTarget: (map['dailyCalorieTarget'] as num?)?.toDouble() ?? 2000.0,
      dailyStepGoal: (map['dailyStepGoal'] as num?)?.toInt() ?? 10000,
      dailyWaterGoal: (map['dailyWaterGoal'] as num?)?.toInt() ?? 2500,
      proteinTarget: (map['proteinTarget'] as num?)?.toDouble() ?? 130.0,
      carbsTarget: (map['carbsTarget'] as num?)?.toDouble() ?? 220.0,
      fatTarget: (map['fatTarget'] as num?)?.toDouble() ?? 65.0,
      fiberTarget: (map['fiberTarget'] as num?)?.toDouble() ?? 30.0,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
    );
  }
}

class FoodItem {
  final String id;
  final String name;
  final String category; // 'Breakfast', 'Rice', 'Protein', 'Vegetables', 'Snacks', 'Drinks', 'Custom'
  final double servingSize;
  final String servingUnit; // 'g', 'ml', 'piece', 'cup', 'bowl', 'slice'
  final double calories; // kcal per serving
  final double protein; // g per serving
  final double carbs; // g per serving
  final double fat; // g per serving
  final double fiber; // g per serving
  final bool isCustom;
  final bool isFavorite;

  FoodItem({
    String? id,
    required this.name,
    required this.category,
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.isCustom = false,
    this.isFavorite = false,
  }) : id = id ?? const Uuid().v4();

  FoodItem copyWith({
    String? id,
    String? name,
    String? category,
    double? servingSize,
    String? servingUnit,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    bool? isCustom,
    bool? isFavorite,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      isCustom: isCustom ?? this.isCustom,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'isCustom': isCustom ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String? ?? 'General',
      servingSize: (map['servingSize'] as num?)?.toDouble() ?? 100.0,
      servingUnit: map['servingUnit'] as String? ?? 'g',
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      fiber: (map['fiber'] as num?)?.toDouble() ?? 0.0,
      isCustom: (map['isCustom'] as int? ?? 0) == 1,
      isFavorite: (map['isFavorite'] as int? ?? 0) == 1,
    );
  }
}

class FoodLog {
  final String id;
  final String foodId;
  final String foodName;
  final String mealType; // 'Breakfast', 'Lunch', 'Dinner', 'Snack'
  final double quantity; // in serving units (e.g. 150g or 2 pieces)
  final String servingUnit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final String loggedAt; // ISO8601 string or HH:mm
  final String date; // YYYY-MM-DD

  FoodLog({
    String? id,
    required this.foodId,
    required this.foodName,
    required this.mealType,
    required this.quantity,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    String? loggedAt,
    required this.date,
  })  : id = id ?? const Uuid().v4(),
        loggedAt = loggedAt ?? DateTime.now().toIso8601String();

  FoodLog copyWith({
    String? id,
    String? foodId,
    String? foodName,
    String? mealType,
    double? quantity,
    String? servingUnit,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    String? loggedAt,
    String? date,
  }) {
    return FoodLog(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      mealType: mealType ?? this.mealType,
      quantity: quantity ?? this.quantity,
      servingUnit: servingUnit ?? this.servingUnit,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      loggedAt: loggedAt ?? this.loggedAt,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'foodId': foodId,
      'foodName': foodName,
      'mealType': mealType,
      'quantity': quantity,
      'servingUnit': servingUnit,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'loggedAt': loggedAt,
      'date': date,
    };
  }

  factory FoodLog.fromMap(Map<String, dynamic> map) {
    return FoodLog(
      id: map['id'] as String,
      foodId: map['foodId'] as String,
      foodName: map['foodName'] as String,
      mealType: map['mealType'] as String,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      servingUnit: map['servingUnit'] as String? ?? 'g',
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      fiber: (map['fiber'] as num?)?.toDouble() ?? 0.0,
      loggedAt: map['loggedAt'] as String? ?? DateTime.now().toIso8601String(),
      date: map['date'] as String,
    );
  }
}

class StepLog {
  final String id;
  final String date; // YYYY-MM-DD
  final int steps;
  final String source; // 'sensor' or 'manual'
  final double distanceKm;
  final int activeMinutes;
  final double estimatedCaloriesBurned;

  StepLog({
    String? id,
    required this.date,
    required this.steps,
    this.source = 'sensor',
    double? distanceKm,
    int? activeMinutes,
    double? estimatedCaloriesBurned,
  })  : id = id ?? const Uuid().v4(),
        distanceKm = distanceKm ?? (steps * 0.000762),
        activeMinutes = activeMinutes ?? (steps ~/ 100),
        estimatedCaloriesBurned = estimatedCaloriesBurned ?? (steps * 0.04);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'steps': steps,
      'source': source,
      'distanceKm': distanceKm,
      'activeMinutes': activeMinutes,
      'estimatedCaloriesBurned': estimatedCaloriesBurned,
    };
  }

  factory StepLog.fromMap(Map<String, dynamic> map) {
    return StepLog(
      id: map['id'] as String,
      date: map['date'] as String,
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      source: map['source'] as String? ?? 'sensor',
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      activeMinutes: (map['activeMinutes'] as num?)?.toInt() ?? 0,
      estimatedCaloriesBurned: (map['estimatedCaloriesBurned'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WaterLog {
  final String id;
  final String date; // YYYY-MM-DD
  final int amountMl;
  final String loggedAt;

  WaterLog({
    String? id,
    required this.date,
    required this.amountMl,
    String? loggedAt,
  })  : id = id ?? const Uuid().v4(),
        loggedAt = loggedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'amountMl': amountMl,
      'loggedAt': loggedAt,
    };
  }

  factory WaterLog.fromMap(Map<String, dynamic> map) {
    return WaterLog(
      id: map['id'] as String,
      date: map['date'] as String,
      amountMl: (map['amountMl'] as num?)?.toInt() ?? 250,
      loggedAt: map['loggedAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}

class WeightLog {
  final String id;
  final String date; // YYYY-MM-DD
  final double weightKg;
  final String? notes;

  WeightLog({
    String? id,
    required this.date,
    required this.weightKg,
    this.notes,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'weightKg': weightKg,
      'notes': notes,
    };
  }

  factory WeightLog.fromMap(Map<String, dynamic> map) {
    return WeightLog(
      id: map['id'] as String,
      date: map['date'] as String,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 70.0,
      notes: map['notes'] as String?,
    );
  }
}
