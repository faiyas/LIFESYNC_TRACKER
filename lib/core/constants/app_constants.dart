import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, highContrast }

enum TaskPriority { low, medium, high, urgent }

enum LoanType { personal, home, auto, education, business, creditCard, other }

enum DebtType { lent, borrowed }

enum InvestmentType { stock, mutualFund, sip, gold, crypto, fixedDeposit, bond, realEstate }

enum InsuranceType { vehicle, health, life, property }

enum VehicleServiceType { generalService, oilChange, tyreChange, batteryChange, repair, inspection }

enum AssetCategory { cash, bank, gold, land, vehicle, house, jewelry, electronics, digital, other }

enum DocumentCategory { passport, pan, aadhar, drivingLicense, certificate, receipt, invoice, medical, property, password, secureNote }

class AppConstants {
  static const String appName = 'LifeSync Tracker';
  static const String appVersion = '2.0.0';

  static const List<String> defaultCurrencies = ['USD', 'EUR', 'GBP', 'INR', 'JPY', 'CAD', 'AUD', 'SGD'];

  static const List<Map<String, dynamic>> defaultCategories = [
    {'name': 'Food & Dining', 'icon': Icons.restaurant, 'color': Colors.orange},
    {'name': 'Shopping', 'icon': Icons.shopping_bag, 'color': Colors.purple},
    {'name': 'Housing', 'icon': Icons.home, 'color': Colors.blue},
    {'name': 'Transportation', 'icon': Icons.directions_car, 'color': Colors.red},
    {'name': 'Vehicle', 'icon': Icons.build, 'color': Colors.amber},
    {'name': 'Entertainment', 'icon': Icons.movie, 'color': Colors.pink},
    {'name': 'Bills & Utilities', 'icon': Icons.receipt, 'color': Colors.teal},
    {'name': 'Health & Fitness', 'icon': Icons.fitness_center, 'color': Colors.green},
    {'name': 'Travel', 'icon': Icons.flight, 'color': Colors.indigo},
    {'name': 'Education', 'icon': Icons.school, 'color': Colors.deepOrange},
    {'name': 'Business', 'icon': Icons.business_center, 'color': Colors.cyan},
    {'name': 'Other', 'icon': Icons.category, 'color': Colors.grey},
  ];
}
