import 'package:uuid/uuid.dart';
export 'my_day_models.dart';

const uuid = Uuid();

class Profile {
  final String id;
  final String name;
  final String? pin;
  final String? recoveryQuestion;
  final String? recoveryAnswer;
  final bool isDefault;
  final String createdAt;

  Profile({
    String? id,
    required this.name,
    this.pin,
    this.recoveryQuestion,
    this.recoveryAnswer,
    this.isDefault = false,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pin': pin,
      'recoveryQuestion': recoveryQuestion,
      'recoveryAnswer': recoveryAnswer,
      'isDefault': isDefault ? 1 : 0,
      'createdAt': createdAt,
    };
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'],
      name: map['name'],
      pin: map['pin'],
      recoveryQuestion: map['recoveryQuestion'],
      recoveryAnswer: map['recoveryAnswer'],
      isDefault: (map['isDefault'] ?? 0) == 1,
      createdAt: map['createdAt'],
    );
  }
}

class Expense {
  final String id;
  final String profileId;
  final double amount;
  final String categoryId;
  final String paymentMethod;
  final String date;
  final String? time;
  final String? notes;
  final String? tags;
  final String? receiptUri;
  final String? location;
  final String currency;
  final bool isRecurring;
  final String createdAt;

  Expense({
    String? id,
    required this.profileId,
    required this.amount,
    required this.categoryId,
    required this.paymentMethod,
    required this.date,
    this.time,
    this.notes,
    this.tags,
    this.receiptUri,
    this.location,
    this.currency = 'INR',
    this.isRecurring = false,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'amount': amount,
      'categoryId': categoryId,
      'paymentMethod': paymentMethod,
      'date': date,
      'time': time,
      'notes': notes,
      'tags': tags,
      'receiptUri': receiptUri,
      'location': location,
      'currency': currency,
      'isRecurring': isRecurring ? 1 : 0,
      'createdAt': createdAt,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      profileId: map['profileId'],
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'],
      paymentMethod: map['paymentMethod'],
      date: map['date'],
      time: map['time'],
      notes: map['notes'],
      tags: map['tags'],
      receiptUri: map['receiptUri'],
      location: map['location'],
      currency: map['currency'] ?? 'USD',
      isRecurring: (map['isRecurring'] ?? 0) == 1,
      createdAt: map['createdAt'],
    );
  }
}

class Income {
  final String id;
  final String profileId;
  final double amount;
  final String categoryId;
  final String source;
  final String paymentMethod;
  final String date;
  final bool isTaxRelevant;
  final bool isRecurring;
  final String? notes;
  final String createdAt;

  Income({
    String? id,
    required this.profileId,
    required this.amount,
    required this.categoryId,
    required this.source,
    required this.paymentMethod,
    required this.date,
    this.isTaxRelevant = false,
    this.isRecurring = false,
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'amount': amount,
      'categoryId': categoryId,
      'source': source,
      'paymentMethod': paymentMethod,
      'date': date,
      'isTaxRelevant': isTaxRelevant ? 1 : 0,
      'isRecurring': isRecurring ? 1 : 0,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      id: map['id'],
      profileId: map['profileId'],
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'],
      source: map['source'],
      paymentMethod: map['paymentMethod'],
      date: map['date'],
      isTaxRelevant: (map['isTaxRelevant'] ?? 0) == 1,
      isRecurring: (map['isRecurring'] ?? 0) == 1,
      notes: map['notes'],
      createdAt: map['createdAt'],
    );
  }
}

class Bill {
  final String id;
  final String profileId;
  final String title;
  final double amount;
  final String dueDate;
  final String? categoryId;
  final String? fileUri;
  final String? warrantyExpiry;
  final bool isPaid;
  final String? notes;
  final String createdAt;

  Bill({
    String? id,
    required this.profileId,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.categoryId,
    this.fileUri,
    this.warrantyExpiry,
    this.isPaid = false,
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'amount': amount,
      'dueDate': dueDate,
      'categoryId': categoryId,
      'fileUri': fileUri,
      'warrantyExpiry': warrantyExpiry,
      'isPaid': isPaid ? 1 : 0,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'],
      profileId: map['profileId'],
      title: map['title'],
      amount: (map['amount'] as num).toDouble(),
      dueDate: map['dueDate'],
      categoryId: map['categoryId'],
      fileUri: map['fileUri'],
      warrantyExpiry: map['warrantyExpiry'],
      isPaid: (map['isPaid'] ?? 0) == 1,
      notes: map['notes'],
      createdAt: map['createdAt'],
    );
  }
}

class Todo {
  final String id;
  final String profileId;
  final String title;
  final String? description;
  final String priority; // low, medium, high
  final String? category;
  final String? dueDate;
  final bool isCompleted;
  final bool isPinned;
  final bool isArchived;
  final bool isRecurring;
  final String createdAt;

  Todo({
    String? id,
    required this.profileId,
    required this.title,
    this.description,
    this.priority = 'medium',
    this.category,
    this.dueDate,
    this.isCompleted = false,
    this.isPinned = false,
    this.isArchived = false,
    this.isRecurring = false,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'description': description,
      'priority': priority,
      'category': category,
      'dueDate': dueDate,
      'isCompleted': isCompleted ? 1 : 0,
      'isPinned': isPinned ? 1 : 0,
      'isArchived': isArchived ? 1 : 0,
      'isRecurring': isRecurring ? 1 : 0,
      'createdAt': createdAt,
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'],
      profileId: map['profileId'],
      title: map['title'],
      description: map['description'],
      priority: map['priority'] ?? 'medium',
      category: map['category'],
      dueDate: map['dueDate'],
      isCompleted: (map['isCompleted'] ?? 0) == 1,
      isPinned: (map['isPinned'] ?? 0) == 1,
      isArchived: (map['isArchived'] ?? 0) == 1,
      isRecurring: (map['isRecurring'] ?? 0) == 1,
      createdAt: map['createdAt'],
    );
  }
}

class Subtask {
  final String id;
  final String todoId;
  final String title;
  final bool isCompleted;

  Subtask({
    String? id,
    required this.todoId,
    required this.title,
    this.isCompleted = false,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'todoId': todoId,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'],
      todoId: map['todoId'],
      title: map['title'],
      isCompleted: (map['isCompleted'] ?? 0) == 1,
    );
  }
}

class Reminder {
  final String id;
  final String profileId;
  final String title;
  final String dateTime;
  final String repeatType;
  final String? linkedEntityId;
  final String? linkedEntityType;
  final String? notes;
  final String createdAt;

  Reminder({
    String? id,
    required this.profileId,
    required this.title,
    required this.dateTime,
    this.repeatType = 'none',
    this.linkedEntityId,
    this.linkedEntityType,
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'dateTime': dateTime,
      'repeatType': repeatType,
      'linkedEntityId': linkedEntityId,
      'linkedEntityType': linkedEntityType,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      profileId: map['profileId'],
      title: map['title'],
      dateTime: map['dateTime'],
      repeatType: map['repeatType'] ?? 'none',
      linkedEntityId: map['linkedEntityId'],
      linkedEntityType: map['linkedEntityType'],
      notes: map['notes'],
      createdAt: map['createdAt'],
    );
  }
}

class Note {
  final String id;
  final String profileId;
  final String title;
  final String content;
  final String folder;
  final String? tags;
  final bool isPinned;
  final bool isLocked;
  final String createdAt;
  final String updatedAt;

  Note({
    String? id,
    required this.profileId,
    required this.title,
    required this.content,
    this.folder = 'General',
    this.tags,
    this.isPinned = false,
    this.isLocked = false,
    String? createdAt,
    String? updatedAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'content': content,
      'folder': folder,
      'tags': tags,
      'isPinned': isPinned ? 1 : 0,
      'isLocked': isLocked ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      profileId: map['profileId'],
      title: map['title'],
      content: map['content'],
      folder: map['folder'] ?? 'General',
      tags: map['tags'],
      isPinned: (map['isPinned'] ?? 0) == 1,
      isLocked: (map['isLocked'] ?? 0) == 1,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }
}

class Habit {
  final String id;
  final String profileId;
  final String title;
  final String? category;
  final int targetDaysPerWeek;
  final String? icon;
  final String? color;
  final String? reminderTime;
  final String createdAt;

  Habit({
    String? id,
    required this.profileId,
    required this.title,
    this.category,
    this.targetDaysPerWeek = 7,
    this.icon,
    this.color,
    this.reminderTime,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'category': category,
      'targetDaysPerWeek': targetDaysPerWeek,
      'icon': icon,
      'color': color,
      'reminderTime': reminderTime,
      'createdAt': createdAt,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'],
      profileId: map['profileId'],
      title: map['title'],
      category: map['category'],
      targetDaysPerWeek: map['targetDaysPerWeek'] ?? 7,
      icon: map['icon'],
      color: map['color'],
      reminderTime: map['reminderTime'],
      createdAt: map['createdAt'],
    );
  }
}

class HabitLog {
  final String id;
  final String habitId;
  final String date;
  final bool status;

  HabitLog({
    String? id,
    required this.habitId,
    required this.date,
    this.status = true,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habitId': habitId,
      'date': date,
      'status': status ? 1 : 0,
    };
  }

  factory HabitLog.fromMap(Map<String, dynamic> map) {
    return HabitLog(
      id: map['id'],
      habitId: map['habitId'],
      date: map['date'],
      status: (map['status'] ?? 1) == 1,
    );
  }
}

class JournalEntry {
  final String id;
  final String profileId;
  final String date;
  final int mood; // 1-5 rating
  final String content;
  final String? tags;
  final String? imageUri;
  final String? audioUri;
  final String createdAt;

  JournalEntry({
    String? id,
    required this.profileId,
    required this.date,
    required this.mood,
    required this.content,
    this.tags,
    this.imageUri,
    this.audioUri,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'date': date,
      'mood': mood,
      'content': content,
      'tags': tags,
      'imageUri': imageUri,
      'audioUri': audioUri,
      'createdAt': createdAt,
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'],
      profileId: map['profileId'],
      date: map['date'],
      mood: map['mood'] ?? 3,
      content: map['content'],
      tags: map['tags'],
      imageUri: map['imageUri'],
      audioUri: map['audioUri'],
      createdAt: map['createdAt'],
    );
  }
}

class Budget {
  final String id;
  final String profileId;
  final String categoryId;
  final double monthlyLimit;
  final String monthYear; // e.g. 2026-08

  Budget({
    String? id,
    required this.profileId,
    required this.categoryId,
    required this.monthlyLimit,
    required this.monthYear,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'categoryId': categoryId,
      'monthlyLimit': monthlyLimit,
      'monthYear': monthYear,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      profileId: map['profileId'],
      categoryId: map['categoryId'],
      monthlyLimit: (map['monthlyLimit'] as num).toDouble(),
      monthYear: map['monthYear'],
    );
  }
}

class SavingsGoal {
  final String id;
  final String profileId;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final String? deadline;
  final String? category;
  final String? icon;
  final String createdAt;

  SavingsGoal({
    String? id,
    required this.profileId,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.deadline,
    this.category,
    this.icon,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': deadline,
      'category': category,
      'icon': icon,
      'createdAt': createdAt,
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'],
      profileId: map['profileId'],
      title: map['title'],
      targetAmount: (map['targetAmount'] as num).toDouble(),
      currentAmount: (map['currentAmount'] as num).toDouble(),
      deadline: map['deadline'],
      category: map['category'],
      icon: map['icon'],
      createdAt: map['createdAt'],
    );
  }
}

class Loan {
  final String id;
  final String profileId;
  final String title;
  final String type; // lent, borrowed
  final double principalAmount;
  final double interestRate;
  final int tenureMonths;
  final String startDate;
  final double monthlyEmi;
  final String? notes;
  final String createdAt;

  Loan({
    String? id,
    required this.profileId,
    required this.title,
    required this.type,
    required this.principalAmount,
    required this.interestRate,
    required this.tenureMonths,
    required this.startDate,
    required this.monthlyEmi,
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'type': type,
      'principalAmount': principalAmount,
      'interestRate': interestRate,
      'tenureMonths': tenureMonths,
      'startDate': startDate,
      'monthlyEmi': monthlyEmi,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'],
      profileId: map['profileId'],
      title: map['title'],
      type: map['type'],
      principalAmount: (map['principalAmount'] as num).toDouble(),
      interestRate: (map['interestRate'] as num).toDouble(),
      tenureMonths: map['tenureMonths'] ?? 12,
      startDate: map['startDate'],
      monthlyEmi: (map['monthlyEmi'] as num).toDouble(),
      notes: map['notes'],
      createdAt: map['createdAt'],
    );
  }
}

class Subscription {
  final String id;
  final String profileId;
  final String name;
  final double cost;
  final String billingCycle;
  final String nextBillingDate;
  final String? category;
  final bool isPaused;
  final String? notes;

  Subscription({
    String? id,
    required this.profileId,
    required this.name,
    required this.cost,
    this.billingCycle = 'monthly',
    required this.nextBillingDate,
    this.category,
    this.isPaused = false,
    this.notes,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'name': name,
      'cost': cost,
      'billingCycle': billingCycle,
      'nextBillingDate': nextBillingDate,
      'category': category,
      'isPaused': isPaused ? 1 : 0,
      'notes': notes,
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'],
      profileId: map['profileId'],
      name: map['name'],
      cost: (map['cost'] as num).toDouble(),
      billingCycle: map['billingCycle'] ?? 'monthly',
      nextBillingDate: map['nextBillingDate'],
      category: map['category'],
      isPaused: (map['isPaused'] ?? 0) == 1,
      notes: map['notes'],
    );
  }
}

class Vehicle {
  final String id;
  final String profileId;
  final String name;
  final String? model;
  final String? licensePlate;
  final String fuelType;

  Vehicle({
    String? id,
    required this.profileId,
    required this.name,
    this.model,
    this.licensePlate,
    this.fuelType = 'Petrol',
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'name': name,
      'model': model,
      'licensePlate': licensePlate,
      'fuelType': fuelType,
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'],
      profileId: map['profileId'],
      name: map['name'],
      model: map['model'],
      licensePlate: map['licensePlate'],
      fuelType: map['fuelType'] ?? 'Petrol',
    );
  }
}

class Customer {
  final String id;
  final String profileId;
  final String name;
  final String mobile;
  final String? altMobile;
  final String? address;
  final String? gpsLocation;
  final String? photoUri;
  final String status; // active, inactive
  final String? notes;
  final String createdAt;

  Customer({
    String? id,
    required this.profileId,
    required this.name,
    required this.mobile,
    this.altMobile,
    this.address,
    this.gpsLocation,
    this.photoUri,
    this.status = 'active',
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'name': name,
      'mobile': mobile,
      'altMobile': altMobile,
      'address': address,
      'gpsLocation': gpsLocation,
      'photoUri': photoUri,
      'status': status,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      profileId: map['profileId'],
      name: map['name'],
      mobile: map['mobile'],
      altMobile: map['altMobile'],
      address: map['address'],
      gpsLocation: map['gpsLocation'],
      photoUri: map['photoUri'],
      status: map['status'] ?? 'active',
      notes: map['notes'],
      createdAt: map['createdAt'],
    );
  }
}

class CustomerJob {
  final String id;
  final String customerId;
  final String description;
  final String category;
  final String status; // pending, in_progress, completed
  final String startDate;
  final String? endDate;
  final double labourCost;
  final double materialCost;
  final double petrolCost;
  final double miscCost;
  final double advanceReceived;
  final double pendingAmount;
  final String? notes;
  final String createdAt;

  CustomerJob({
    String? id,
    required this.customerId,
    required this.description,
    this.category = 'General',
    this.status = 'pending',
    required this.startDate,
    this.endDate,
    this.labourCost = 0.0,
    this.materialCost = 0.0,
    this.petrolCost = 0.0,
    this.miscCost = 0.0,
    this.advanceReceived = 0.0,
    required this.pendingAmount,
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'description': description,
      'category': category,
      'status': status,
      'startDate': startDate,
      'endDate': endDate,
      'labourCost': labourCost,
      'materialCost': materialCost,
      'petrolCost': petrolCost,
      'miscCost': miscCost,
      'advanceReceived': advanceReceived,
      'pendingAmount': pendingAmount,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory CustomerJob.fromMap(Map<String, dynamic> map) {
    return CustomerJob(
      id: map['id'],
      customerId: map['customerId'],
      description: map['description'],
      category: map['category'] ?? 'General',
      status: map['status'] ?? 'pending',
      startDate: map['startDate'],
      endDate: map['endDate'],
      labourCost: (map['labourCost'] as num?)?.toDouble() ?? 0.0,
      materialCost: (map['materialCost'] as num?)?.toDouble() ?? 0.0,
      petrolCost: (map['petrolCost'] as num?)?.toDouble() ?? 0.0,
      miscCost: (map['miscCost'] as num?)?.toDouble() ?? 0.0,
      advanceReceived: (map['advanceReceived'] as num?)?.toDouble() ?? 0.0,
      pendingAmount: (map['pendingAmount'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      createdAt: map['createdAt'],
    );
  }
}

class BorrowedMoney {
  final String id;
  final String profileId;
  final String personName;
  final String type; // borrowed (from), lent (to)
  final double amount;
  final double interestRate;
  final String dueDate;
  final String status; // pending, paid
  final String? notes;
  final String createdAt;

  BorrowedMoney({
    String? id,
    required this.profileId,
    required this.personName,
    required this.type,
    required this.amount,
    this.interestRate = 0.0,
    required this.dueDate,
    this.status = 'pending',
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'personName': personName,
      'type': type,
      'amount': amount,
      'interestRate': interestRate,
      'dueDate': dueDate,
      'status': status,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory BorrowedMoney.fromMap(Map<String, dynamic> map) {
    return BorrowedMoney(
      id: map['id'],
      profileId: map['profileId'],
      personName: map['personName'],
      type: map['type'],
      amount: (map['amount'] as num).toDouble(),
      interestRate: (map['interestRate'] as num?)?.toDouble() ?? 0.0,
      dueDate: map['dueDate'],
      status: map['status'] ?? 'pending',
      notes: map['notes'],
      createdAt: map['createdAt'],
    );
  }
}

class DocumentItem {
  final String id;
  final String profileId;
  final String category;
  final String title;
  final String filePath;
  final String fileType; // pdf, image, jpg, png, word, excel, txt
  final String? extractedText; // OCR extracted text
  final String? thumbnailPath;
  final int? fileSize;
  final String? tags;
  final bool isPasswordProtected;
  final bool isFavorite;
  final String? notes;
  final String createdAt;
  final String? updatedAt;

  DocumentItem({
    String? id,
    required this.profileId,
    required this.category,
    required this.title,
    required this.filePath,
    required this.fileType,
    this.extractedText,
    this.thumbnailPath,
    this.fileSize,
    this.tags,
    this.isPasswordProtected = false,
    this.isFavorite = false,
    this.notes,
    String? createdAt,
    String? updatedAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  DocumentItem copyWith({
    String? id,
    String? profileId,
    String? category,
    String? title,
    String? filePath,
    String? fileType,
    String? extractedText,
    String? thumbnailPath,
    int? fileSize,
    String? tags,
    bool? isPasswordProtected,
    bool? isFavorite,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      category: category ?? this.category,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      extractedText: extractedText ?? this.extractedText,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fileSize: fileSize ?? this.fileSize,
      tags: tags ?? this.tags,
      isPasswordProtected: isPasswordProtected ?? this.isPasswordProtected,
      isFavorite: isFavorite ?? this.isFavorite,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'category': category,
      'title': title,
      'filePath': filePath,
      'fileType': fileType,
      'extractedText': extractedText,
      'thumbnailPath': thumbnailPath,
      'fileSize': fileSize,
      'tags': tags,
      'isPasswordProtected': isPasswordProtected ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory DocumentItem.fromMap(Map<String, dynamic> map) {
    return DocumentItem(
      id: map['id'],
      profileId: map['profileId'],
      category: map['category'] ?? 'General',
      title: map['title'],
      filePath: map['filePath'],
      fileType: map['fileType'] ?? 'pdf',
      extractedText: map['extractedText'],
      thumbnailPath: map['thumbnailPath'],
      fileSize: map['fileSize'] != null ? (map['fileSize'] as num).toInt() : null,
      tags: map['tags'],
      isPasswordProtected: (map['isPasswordProtected'] ?? 0) == 1,
      isFavorite: (map['isFavorite'] ?? 0) == 1,
      notes: map['notes'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }
}

class InventoryItem {
  final String id;
  final String profileId;
  final String name;
  final String category;
  final int quantity;
  final String unit; // pcs, kg, ltr, box
  final double purchasePrice;
  final double sellingPrice;
  final String? supplier;
  final int stockAlertThreshold;
  final String? notes;
  final String createdAt;

  InventoryItem({
    String? id,
    required this.profileId,
    required this.name,
    this.category = 'General',
    required this.quantity,
    this.unit = 'pcs',
    required this.purchasePrice,
    required this.sellingPrice,
    this.supplier,
    this.stockAlertThreshold = 5,
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'supplier': supplier,
      'stockAlertThreshold': stockAlertThreshold,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'],
      profileId: map['profileId'],
      name: map['name'],
      category: map['category'] ?? 'General',
      quantity: map['quantity'] ?? 0,
      unit: map['unit'] ?? 'pcs',
      purchasePrice: (map['purchasePrice'] as num).toDouble(),
      sellingPrice: (map['sellingPrice'] as num).toDouble(),
      supplier: map['supplier'],
      stockAlertThreshold: map['stockAlertThreshold'] ?? 5,
      notes: map['notes'],
      createdAt: map['createdAt'],
    );
  }
}

class Investment {
  final String id;
  final String profileId;
  final String title;
  final String type;
  final String? symbol;
  final double quantity;
  final double buyPrice;
  final double currentPrice;
  final String? notes;
  final String createdAt;

  Investment({
    String? id,
    required this.profileId,
    required this.title,
    required this.type,
    this.symbol,
    this.quantity = 1.0,
    required this.buyPrice,
    required this.currentPrice,
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  double get totalInvested => quantity * buyPrice;
  double get totalCurrentValue => quantity * currentPrice;
  double get profitLoss => totalCurrentValue - totalInvested;
  double get roiPercentage => totalInvested > 0 ? (profitLoss / totalInvested) * 100 : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'type': type,
      'symbol': symbol,
      'quantity': quantity,
      'buyPrice': buyPrice,
      'currentPrice': currentPrice,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory Investment.fromMap(Map<String, dynamic> map) {
    return Investment(
      id: map['id'],
      profileId: map['profileId'],
      title: map['title'],
      type: map['type'],
      symbol: map['symbol'],
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      buyPrice: (map['buyPrice'] as num).toDouble(),
      currentPrice: (map['currentPrice'] as num).toDouble(),
      notes: map['notes'],
      createdAt: map['createdAt'],
    );
  }
}

class InsurancePolicy {
  final String id;
  final String profileId;
  final String title;
  final String type;
  final String provider;
  final String? policyNumber;
  final double premiumAmount;
  final String renewalDate;
  final String? claimsHistory;
  final String? notes;
  final String createdAt;

  InsurancePolicy({
    String? id,
    required this.profileId,
    required this.title,
    required this.type,
    required this.provider,
    this.policyNumber,
    required this.premiumAmount,
    required this.renewalDate,
    this.claimsHistory,
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'type': type,
      'provider': provider,
      'policyNumber': policyNumber,
      'premiumAmount': premiumAmount,
      'renewalDate': renewalDate,
      'claimsHistory': claimsHistory,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory InsurancePolicy.fromMap(Map<String, dynamic> map) {
    return InsurancePolicy(
      id: map['id'],
      profileId: map['profileId'],
      title: map['title'],
      type: map['type'],
      provider: map['provider'],
      policyNumber: map['policyNumber'],
      premiumAmount: (map['premiumAmount'] as num).toDouble(),
      renewalDate: map['renewalDate'],
      claimsHistory: map['claimsHistory'],
      notes: map['notes'],
      createdAt: map['createdAt'],
    );
  }
}

class TaxRecord {
  final String id;
  final String profileId;
  final int taxYear;
  final double incomeTaxPaid;
  final double gstPaid;
  final double professionalTax;
  final double deductions;
  final String? notes;
  final String createdAt;

  TaxRecord({
    String? id,
    required this.profileId,
    required this.taxYear,
    this.incomeTaxPaid = 0.0,
    this.gstPaid = 0.0,
    this.professionalTax = 0.0,
    this.deductions = 0.0,
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  double get totalTaxPaid => incomeTaxPaid + gstPaid + professionalTax;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'taxYear': taxYear,
      'incomeTaxPaid': incomeTaxPaid,
      'gstPaid': gstPaid,
      'professionalTax': professionalTax,
      'deductions': deductions,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory TaxRecord.fromMap(Map<String, dynamic> map) {
    return TaxRecord(
      id: map['id'],
      profileId: map['profileId'],
      taxYear: map['taxYear'],
      incomeTaxPaid: (map['incomeTaxPaid'] as num?)?.toDouble() ?? 0.0,
      gstPaid: (map['gstPaid'] as num?)?.toDouble() ?? 0.0,
      professionalTax: (map['professionalTax'] as num?)?.toDouble() ?? 0.0,
      deductions: (map['deductions'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      createdAt: map['createdAt'],
    );
  }
}

class PhysicalAsset {
  final String id;
  final String profileId;
  final String name;
  final String category;
  final String purchaseDate;
  final double purchaseValue;
  final double currentValue;
  final double depreciationRate;
  final String? notes;
  final String createdAt;

  PhysicalAsset({
    String? id,
    required this.profileId,
    required this.name,
    required this.category,
    required this.purchaseDate,
    required this.purchaseValue,
    required this.currentValue,
    this.depreciationRate = 0.0,
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'name': name,
      'category': category,
      'purchaseDate': purchaseDate,
      'purchaseValue': purchaseValue,
      'currentValue': currentValue,
      'depreciationRate': depreciationRate,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory PhysicalAsset.fromMap(Map<String, dynamic> map) {
    return PhysicalAsset(
      id: map['id'],
      profileId: map['profileId'],
      name: map['name'],
      category: map['category'],
      purchaseDate: map['purchaseDate'],
      purchaseValue: (map['purchaseValue'] as num).toDouble(),
      currentValue: (map['currentValue'] as num).toDouble(),
      depreciationRate: (map['depreciationRate'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      createdAt: map['createdAt'],
    );
  }
}

class DigitalVaultItem {
  final String id;
  final String profileId;
  final String title;
  final String category;
  final String encryptedData;
  final String? attachmentPath;
  final bool isPinProtected;
  final String createdAt;

  DigitalVaultItem({
    String? id,
    required this.profileId,
    required this.title,
    required this.category,
    required this.encryptedData,
    this.attachmentPath,
    this.isPinProtected = true,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'category': category,
      'encryptedData': encryptedData,
      'attachmentPath': attachmentPath,
      'isPinProtected': isPinProtected ? 1 : 0,
      'createdAt': createdAt,
    };
  }

  factory DigitalVaultItem.fromMap(Map<String, dynamic> map) {
    return DigitalVaultItem(
      id: map['id'],
      profileId: map['profileId'],
      title: map['title'],
      category: map['category'],
      encryptedData: map['encryptedData'],
      attachmentPath: map['attachmentPath'],
      isPinProtected: (map['isPinProtected'] ?? 1) == 1,
      createdAt: map['createdAt'],
    );
  }
}

class SavedLocation {
  final String id;
  final String profileId;
  final String title;
  final String address;
  final double latitude;
  final double longitude;
  final String category;
  final String? notes;
  final String createdAt;

  SavedLocation({
    String? id,
    this.profileId = 'default_profile',
    required this.title,
    required this.address,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.category = 'Favorite',
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory SavedLocation.fromMap(Map<String, dynamic> map) {
    return SavedLocation(
      id: map['id'],
      profileId: map['profileId'] ?? 'default_profile',
      title: map['title'],
      address: map['address'],
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Favorite',
      notes: map['notes'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class OfflineMap {
  final String id;
  final String profileId;
  final String regionName;
  final double centerLat;
  final double centerLng;
  final int zoomLevel;
  final double sizeMb;
  final String status;
  final String downloadedAt;
  final String? fileUri;

  OfflineMap({
    String? id,
    this.profileId = 'default_profile',
    required this.regionName,
    this.centerLat = 37.7749,
    this.centerLng = -122.4194,
    this.zoomLevel = 12,
    this.sizeMb = 0.0,
    this.status = 'downloaded',
    String? downloadedAt,
    this.fileUri,
  })  : id = id ?? uuid.v4(),
        downloadedAt = downloadedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'regionName': regionName,
      'centerLat': centerLat,
      'centerLng': centerLng,
      'zoomLevel': zoomLevel,
      'sizeMb': sizeMb,
      'status': status,
      'downloadedAt': downloadedAt,
      'fileUri': fileUri,
    };
  }

  factory OfflineMap.fromMap(Map<String, dynamic> map) {
    return OfflineMap(
      id: map['id'],
      profileId: map['profileId'] ?? 'default_profile',
      regionName: map['regionName'],
      centerLat: (map['centerLat'] as num?)?.toDouble() ?? 37.7749,
      centerLng: (map['centerLng'] as num?)?.toDouble() ?? -122.4194,
      zoomLevel: map['zoomLevel'] ?? 12,
      sizeMb: (map['sizeMb'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'downloaded',
      downloadedAt: map['downloadedAt'] ?? DateTime.now().toIso8601String(),
      fileUri: map['fileUri'],
    );
  }
}

class SavedTrip {
  final String id;
  final String profileId;
  final String title;
  final String startLocation;
  final String endLocation;
  final double distanceKm;
  final int durationMins;
  final String mode;
  final String? waypointsJson;
  final String? notes;
  final String createdAt;

  SavedTrip({
    String? id,
    this.profileId = 'default_profile',
    required this.title,
    required this.startLocation,
    required this.endLocation,
    required this.distanceKm,
    required this.durationMins,
    this.mode = 'driving',
    this.waypointsJson,
    this.notes,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'startLocation': startLocation,
      'endLocation': endLocation,
      'distanceKm': distanceKm,
      'durationMins': durationMins,
      'mode': mode,
      'waypointsJson': waypointsJson,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory SavedTrip.fromMap(Map<String, dynamic> map) {
    return SavedTrip(
      id: map['id'],
      profileId: map['profileId'] ?? 'default_profile',
      title: map['title'],
      startLocation: map['startLocation'],
      endLocation: map['endLocation'],
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationMins: map['durationMins'] ?? 0,
      mode: map['mode'] ?? 'driving',
      waypointsJson: map['waypointsJson'],
      notes: map['notes'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class TripPlanModel {
  final String id;
  final String profileId;
  final String title;
  final String destination;
  final String? destinationMapUrl;
  final String startDate;
  final String endDate;
  final double budget;
  final String currency;
  final String status; // 'planned', 'ongoing', 'completed', 'cancelled'
  final String coverCategory; // 'beach', 'mountains', 'city', 'roadtrip', 'heritage', 'general'
  final String? notes;
  final String? checklistJson;
  final String? itineraryJson;
  final String createdAt;

  TripPlanModel({
    String? id,
    this.profileId = 'default_profile',
    required this.title,
    required this.destination,
    this.destinationMapUrl,
    required this.startDate,
    required this.endDate,
    this.budget = 0.0,
    this.currency = 'INR',
    this.status = 'planned',
    this.coverCategory = 'general',
    this.notes,
    this.checklistJson,
    this.itineraryJson,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'destination': destination,
      'destinationMapUrl': destinationMapUrl,
      'startDate': startDate,
      'endDate': endDate,
      'budget': budget,
      'currency': currency,
      'status': status,
      'coverCategory': coverCategory,
      'notes': notes,
      'checklistJson': checklistJson,
      'itineraryJson': itineraryJson,
      'createdAt': createdAt,
    };
  }

  factory TripPlanModel.fromMap(Map<String, dynamic> map) {
    return TripPlanModel(
      id: map['id'],
      profileId: map['profileId'] ?? 'default_profile',
      title: map['title'] ?? '',
      destination: map['destination'] ?? map['title'] ?? '',
      destinationMapUrl: map['destinationMapUrl'],
      startDate: map['startDate'] ?? DateTime.now().toIso8601String().substring(0, 10),
      endDate: map['endDate'] ?? DateTime.now().toIso8601String().substring(0, 10),
      budget: (map['budget'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'INR',
      status: map['status'] ?? 'planned',
      coverCategory: map['coverCategory'] ?? 'general',
      notes: map['notes'],
      checklistJson: map['checklistJson'],
      itineraryJson: map['itineraryJson'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class TripExpense {
  final String id;
  final String tripId;
  final String title;
  final double amount;
  final String category; // 'Transport', 'Stay', 'Food', 'Activities', 'Shopping', 'Fuel', 'Misc'
  final String date;
  final String paymentMethod; // 'Cash', 'UPI', 'Card', 'Net Banking'
  final String? location;
  final String? mapUrl;
  final String? notes;
  final String? receiptUri;
  final String createdAt;

  TripExpense({
    String? id,
    required this.tripId,
    required this.title,
    required this.amount,
    this.category = 'Misc',
    required this.date,
    this.paymentMethod = 'UPI',
    this.location,
    this.mapUrl,
    this.notes,
    this.receiptUri,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date,
      'paymentMethod': paymentMethod,
      'location': location,
      'mapUrl': mapUrl,
      'notes': notes,
      'receiptUri': receiptUri,
      'createdAt': createdAt,
    };
  }

  factory TripExpense.fromMap(Map<String, dynamic> map) {
    return TripExpense(
      id: map['id'],
      tripId: map['tripId'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Misc',
      date: map['date'] ?? DateTime.now().toIso8601String().substring(0, 10),
      paymentMethod: map['paymentMethod'] ?? 'UPI',
      location: map['location'],
      mapUrl: map['mapUrl'],
      notes: map['notes'],
      receiptUri: map['receiptUri'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class TripLocationItem {
  final String id;
  final String tripId; // trip id or 'global'
  final String name;
  final String category; // 'Attraction', 'Stay', 'Food', 'Viewpoint', 'Activity', 'Fuel', 'Shopping', 'General'
  final String? address;
  final String? mapUrl;
  final double latitude;
  final double longitude;
  final String? notes;
  final double estimatedCost;
  final bool isVisited;
  final String createdAt;

  TripLocationItem({
    String? id,
    this.tripId = 'global',
    required this.name,
    this.category = 'Attraction',
    this.address,
    this.mapUrl,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.notes,
    this.estimatedCost = 0.0,
    this.isVisited = false,
    String? createdAt,
  })  : id = id ?? uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'name': name,
      'category': category,
      'address': address,
      'mapUrl': mapUrl,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'estimatedCost': estimatedCost,
      'isVisited': isVisited ? 1 : 0,
      'createdAt': createdAt,
    };
  }

  factory TripLocationItem.fromMap(Map<String, dynamic> map) {
    return TripLocationItem(
      id: map['id'],
      tripId: map['tripId'] ?? 'global',
      name: map['name'] ?? map['title'] ?? '',
      category: map['category'] ?? 'Attraction',
      address: map['address'],
      mapUrl: map['mapUrl'],
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      estimatedCost: (map['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      isVisited: (map['isVisited'] ?? 0) == 1,
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
