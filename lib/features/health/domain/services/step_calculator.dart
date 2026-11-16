class StepCalculator {
  static const List<int> milestones = [
    1000,
    2500,
    5000,
    7500,
    10000,
    12500,
    15000,
  ];

  /// Estimate distance walked in kilometers (average stride ~0.762 meters)
  static double calculateDistanceKm(int steps) {
    return double.parse((steps * 0.000762).toStringAsFixed(2));
  }

  /// Estimate active minutes (brisk walk ~100-110 steps/min)
  static int calculateActiveMinutes(int steps) {
    return (steps / 100).round();
  }

  /// Estimate calories burned (approx ~0.04 kcal per step for average adult)
  static double calculateCaloriesBurned(int steps) {
    return double.parse((steps * 0.04).toStringAsFixed(1));
  }

  /// Check if the current step count crossed a new milestone
  static int? getReachedMilestone(int currentSteps, int previousSteps) {
    for (final milestone in milestones) {
      if (currentSteps >= milestone && previousSteps < milestone) {
        return milestone;
      }
    }
    return null;
  }
}
