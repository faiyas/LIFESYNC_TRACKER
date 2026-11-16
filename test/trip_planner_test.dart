import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync_tracker/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trip Planner & Tracker Models Test', () {
    test('TripPlanModel serialization and budget calculation', () {
      final trip = TripPlanModel(
        title: 'Manali Snow Trek',
        destination: 'Manali, Himachal Pradesh',
        destinationMapUrl: 'https://maps.google.com/?q=Manali',
        startDate: '2026-09-01',
        endDate: '2026-09-06',
        budget: 18000.0,
        status: 'planned',
        coverCategory: 'mountains',
      );

      expect(trip.title, 'Manali Snow Trek');
      expect(trip.destination, 'Manali, Himachal Pradesh');
      expect(trip.budget, 18000.0);
      expect(trip.status, 'planned');

      final map = trip.toMap();
      final fromMap = TripPlanModel.fromMap(map);
      expect(fromMap.title, trip.title);
      expect(fromMap.budget, trip.budget);
      expect(fromMap.destination, trip.destination);
    });

    test('TripExpense serialization', () {
      final exp = TripExpense(
        tripId: 'trip_123',
        title: 'Dinner at Cafe 1947',
        amount: 1450.0,
        category: 'Food',
        date: '2026-09-02',
        paymentMethod: 'UPI',
        location: 'Old Manali',
      );

      expect(exp.amount, 1450.0);
      expect(exp.category, 'Food');

      final map = exp.toMap();
      final fromMap = TripExpense.fromMap(map);
      expect(fromMap.title, exp.title);
      expect(fromMap.amount, 1450.0);
    });

    test('TripLocationItem serialization', () {
      final loc = TripLocationItem(
        tripId: 'trip_123',
        name: 'Solang Valley',
        category: 'Viewpoint',
        address: 'Solang Valley, Manali',
        mapUrl: 'https://maps.google.com/?q=Solang+Valley',
        estimatedCost: 500.0,
        isVisited: false,
      );

      expect(loc.name, 'Solang Valley');
      expect(loc.isVisited, false);

      final map = loc.toMap();
      final fromMap = TripLocationItem.fromMap(map);
      expect(fromMap.name, 'Solang Valley');
      expect(fromMap.isVisited, false);
    });
  });
}
