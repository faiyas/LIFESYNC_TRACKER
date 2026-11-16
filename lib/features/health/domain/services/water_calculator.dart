class WaterCalculator {
  /// Calculate recommended daily water intake in ml based on body weight
  static int calculateRecommendedWater(double weightKg) {
    // 35 ml per kg of body weight
    final recommended = (weightKg * 35).round();
    return (recommended / 250).round() * 250; // Round to nearest 250ml
  }
}
