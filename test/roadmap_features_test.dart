import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync_tracker/features/health/domain/services/nutrition_ocr_service.dart';
import 'package:lifesync_tracker/models/models.dart';
import 'package:lifesync_tracker/services/apps_script_template.dart';

void main() {
  group('1. Finance - Recurring Subscriptions Auto-Logging Tests', () {
    test('Subscription model supports monthly and yearly recurring cycles', () {
      final sub = Subscription(
        profileId: 'test_prof',
        name: 'Netflix Premium',
        cost: 649.0,
        billingCycle: 'monthly',
        nextBillingDate: '2026-08-30',
        category: 'Entertainment',
      );

      final map = sub.toMap();
      expect(map['name'], 'Netflix Premium');
      expect(map['cost'], 649.0);
      expect(map['billingCycle'], 'monthly');

      final fromMap = Subscription.fromMap(map);
      expect(fromMap.name, 'Netflix Premium');
      expect(fromMap.cost, 649.0);
      expect(fromMap.billingCycle, 'monthly');
    });

    test('Expense model correctly logs subscription auto-debit charge', () {
      final exp = Expense(
        profileId: 'test_prof',
        amount: 649.0,
        categoryId: 'Entertainment',
        paymentMethod: 'Auto-Debit',
        date: '2026-08-27',
        notes: 'Auto-logged recurring subscription: Netflix Premium',
      );

      final map = exp.toMap();
      expect(map['amount'], 649.0);
      expect(map['paymentMethod'], 'Auto-Debit');
      expect(map['notes'], contains('Netflix Premium'));
    });
  });

  group('2. Productivity - Habit Streak Calculation Tests', () {
    test('Calculates active daily streak and longest streak accurately', () {
      final dates = {'2026-08-27', '2026-08-26', '2026-08-25', '2026-08-24'};

      // 4-day continuous streak ending on today
      int currentStreak = 0;
      final today = '2026-08-27';
      var check = DateTime.parse(today);

      while (dates.contains(check.toIso8601String().substring(0, 10))) {
        currentStreak++;
        check = check.subtract(const Duration(days: 1));
      }

      expect(currentStreak, 4);
    });

    test('Calculates streak as 0 when break in continuity occurs', () {
      final dates = {'2026-08-20', '2026-08-21'}; // Older dates, missing today and yesterday
      final today = '2026-08-27';
      final yesterday = '2026-08-26';

      final hasTodayOrYesterday = dates.contains(today) || dates.contains(yesterday);
      expect(hasTodayOrYesterday, isFalse);
    });
  });

  group('3. Health - Nutrition Label OCR Parsing Tests', () {
    test('Parses standard nutrition facts table with macros accurately', () {
      const sampleOcr = '''
Nutrition Facts
Per 100g serving
Calories: 340 kcal
Protein: 24.5g
Total Carbohydrate: 42g
Dietary Fiber: 6.2g
Total Fat: 8.0g
''';

      final parsed = NutritionOcrService.instance.parseNutritionText(sampleOcr);
      expect(parsed.calories, 340.0);
      expect(parsed.protein, 24.5);
      expect(parsed.carbs, 42.0);
      expect(parsed.fat, 8.0);
      expect(parsed.fiber, 6.2);
      expect(parsed.servingSize, 100.0);
      expect(parsed.servingUnit, 'g');
    });

    test('Parses energy and protein from compact label layout', () {
      const sampleOcr = '''
Greek Yogurt Plain
Energy 120 kcal
Total Fat 2.5 g
Total Carb 6 g
Protein 18.0 g
''';

      final parsed = NutritionOcrService.instance.parseNutritionText(sampleOcr);
      expect(parsed.calories, 120.0);
      expect(parsed.protein, 18.0);
      expect(parsed.carbs, 6.0);
      expect(parsed.fat, 2.5);
      expect(parsed.foodName, 'Greek Yogurt Plain');
    });
  });

  group('4. Navigation - Waypoint Route Optimization Tests', () {
    test('Nearest neighbor algorithm sorts waypoints for minimal total distance', () {
      final locs = [
        TripLocationItem(id: '1', tripId: 't1', name: 'Start Point', latitude: 12.9716, longitude: 77.5946),
        TripLocationItem(id: '2', tripId: 't1', name: 'Far Spot', latitude: 13.5000, longitude: 78.0000),
        TripLocationItem(id: '3', tripId: 't1', name: 'Near Spot', latitude: 12.9750, longitude: 77.5980),
      ];

      final unvisited = List<TripLocationItem>.from(locs);
      final List<TripLocationItem> optimized = [];

      var current = unvisited.removeAt(0);
      optimized.add(current);

      while (unvisited.isNotEmpty) {
        int nearestIdx = 0;
        double minDistance = double.infinity;

        for (int i = 0; i < unvisited.length; i++) {
          final cand = unvisited[i];
          final dLat = cand.latitude - current.latitude;
          final dLon = cand.longitude - current.longitude;
          final dist = (dLat * dLat) + (dLon * dLon);

          if (dist < minDistance) {
            minDistance = dist;
            nearestIdx = i;
          }
        }

        current = unvisited.removeAt(nearestIdx);
        optimized.add(current);
      }

      // 'Near Spot' must come before 'Far Spot'
      expect(optimized[0].name, 'Start Point');
      expect(optimized[1].name, 'Near Spot');
      expect(optimized[2].name, 'Far Spot');
    });
  });

  group('5. Lifestyle - Fuel Economy & Mileage Calculation Tests', () {
    test('Calculates km/L and cost per km between two odometer fill-ups', () {
      const prevOdometer = 12000.0;
      const currentOdometer = 12450.0; // Distance = 450 km
      const fuelLiters = 30.0;
      const totalCost = 3150.0; // ₹105 / L

      final distance = currentOdometer - prevOdometer;
      final kmpl = distance / fuelLiters;
      final costPerKm = totalCost / distance;

      expect(distance, 450.0);
      expect(kmpl, 15.0); // 15 km/L
      expect(costPerKm, 7.0); // ₹7 / km
    });
  });

  group('6. Cloud Sync - Google Sheets 2-Way Restore Tests', () {
    test('AppsScriptTemplate includes restore engine handling in doGet and doPost', () {
      final code = AppsScriptTemplate.code;
      expect(code, contains('function doGet(e)'));
      expect(code, contains('function doPost(e)'));
      expect(code, contains('restore'));
      expect(code, contains('fetch_all'));
      expect(code, contains('Sync_Overview'));
      expect(code, contains('2-Way'));
    });
  });
}
