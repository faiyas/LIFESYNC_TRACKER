import '../../data/models/health_models.dart';

class WeightProgressSummary {
  final double currentWeight;
  final double startingWeight;
  final double weightChange; // current - start
  final double weeklyAverage;
  final List<WeightLog> logs;

  const WeightProgressSummary({
    required this.currentWeight,
    required this.startingWeight,
    required this.weightChange,
    required this.weeklyAverage,
    required this.logs,
  });
}

class WeightProgressCalculator {
  static WeightProgressSummary calculate(List<WeightLog> logs, double defaultWeight) {
    if (logs.isEmpty) {
      return WeightProgressSummary(
        currentWeight: defaultWeight,
        startingWeight: defaultWeight,
        weightChange: 0.0,
        weeklyAverage: defaultWeight,
        logs: [],
      );
    }

    final sorted = List<WeightLog>.from(logs)..sort((a, b) => a.date.compareTo(b.date));
    final startingWeight = sorted.first.weightKg;
    final currentWeight = sorted.last.weightKg;
    final weightChange = double.parse((currentWeight - startingWeight).toStringAsFixed(1));

    // Calculate last 7 logs average
    final recent = sorted.reversed.take(7).toList();
    final sum = recent.fold<double>(0.0, (prev, e) => prev + e.weightKg);
    final weeklyAvg = double.parse((sum / recent.length).toStringAsFixed(1));

    return WeightProgressSummary(
      currentWeight: currentWeight,
      startingWeight: startingWeight,
      weightChange: weightChange,
      weeklyAverage: weeklyAvg,
      logs: sorted,
    );
  }
}
