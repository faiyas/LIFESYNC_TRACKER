import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/calorie_calculator.dart';
import '../controllers/health_controller.dart';

class HealthProfilePage extends ConsumerStatefulWidget {
  const HealthProfilePage({super.key});

  @override
  ConsumerState<HealthProfilePage> createState() => _HealthProfilePageState();
}

class _HealthProfilePageState extends ConsumerState<HealthProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _customCalorieCtrl;
  late TextEditingController _customStepCtrl;
  late TextEditingController _customWaterCtrl;

  late String _gender;
  late String _activityLevel;
  late String _goal;
  bool _manualOverride = false;

  final Map<String, String> _activityOptions = {
    'sedentary': 'Sedentary (Little to no exercise)',
    'lightly_active': 'Lightly Active (1-3 days/week)',
    'moderately_active': 'Moderately Active (3-5 days/week)',
    'very_active': 'Very Active (6-7 days hard exercise)',
  };

  final Map<String, String> _goalOptions = {
    'lose_weight': 'Lose Weight (Moderate Deficit)',
    'maintain_weight': 'Maintain Weight (TDEE balance)',
    'gain_weight': 'Gain Weight / Muscle (Clean Surplus)',
  };

  @override
  void initState() {
    super.initState();
    final profile = ref.read(healthControllerProvider).profile;
    _ageCtrl = TextEditingController(text: profile.age.toString());
    _heightCtrl = TextEditingController(text: profile.heightCm.toStringAsFixed(0));
    _weightCtrl = TextEditingController(text: profile.weightKg.toStringAsFixed(1));
    _customCalorieCtrl = TextEditingController(text: profile.dailyCalorieTarget.toStringAsFixed(0));
    _customStepCtrl = TextEditingController(text: profile.dailyStepGoal.toString());
    _customWaterCtrl = TextEditingController(text: profile.dailyWaterGoal.toString());

    _gender = profile.gender;
    _activityLevel = profile.activityLevel;
    _goal = profile.goal;
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _customCalorieCtrl.dispose();
    _customStepCtrl.dispose();
    _customWaterCtrl.dispose();
    super.dispose();
  }

  double _getCalculatedCalories() {
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 28;
    final height = double.tryParse(_heightCtrl.text.trim()) ?? 175.0;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 72.0;

    return CalorieCalculator.calculateDailyTarget(
      weightKg: weight,
      heightCm: height,
      age: age,
      gender: _gender,
      activityLevel: _activityLevel,
      goal: _goal,
    );
  }

  double _getCalculatedBMR() {
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 28;
    final height = double.tryParse(_heightCtrl.text.trim()) ?? 175.0;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 72.0;

    return CalorieCalculator.calculateBMR(
      weightKg: weight,
      heightCm: height,
      age: age,
      gender: _gender,
    );
  }

  double _getCalculatedTDEE() {
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 28;
    final height = double.tryParse(_heightCtrl.text.trim()) ?? 175.0;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 72.0;

    return CalorieCalculator.calculateTDEE(
      weightKg: weight,
      heightCm: height,
      age: age,
      gender: _gender,
      activityLevel: _activityLevel,
    );
  }

  void _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final age = int.tryParse(_ageCtrl.text.trim()) ?? 28;
    final height = double.tryParse(_heightCtrl.text.trim()) ?? 175.0;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 72.0;

    final customCal = _manualOverride ? double.tryParse(_customCalorieCtrl.text.trim()) : null;
    final customSteps = int.tryParse(_customStepCtrl.text.trim());
    final customWater = int.tryParse(_customWaterCtrl.text.trim());

    await ref.read(healthControllerProvider.notifier).recalculateAndSaveGoals(
          age: age,
          gender: _gender,
          heightCm: height,
          weightKg: weight,
          activityLevel: _activityLevel,
          goal: _goal,
          customCalorieTarget: customCal,
          customStepGoal: customSteps,
          customWaterGoal: customWater,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health profile & calorie goals updated successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final calculatedTarget = _getCalculatedCalories();
    final bmr = _getCalculatedBMR();
    final tdee = _getCalculatedTDEE();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Health Goals', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Disclaimer Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Calculated using standard metabolic formulas (Mifflin-St Jeor). Estimates are for personal fitness tracking and not medical advice.',
                      style: TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('Personal Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Gender selector
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Male')),
                    selected: _gender == 'male',
                    onSelected: (val) {
                      if (val) setState(() => _gender = 'male');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Female')),
                    selected: _gender == 'female',
                    onSelected: (val) {
                      if (val) setState(() => _gender = 'female');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Age, Height, Weight
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Age (yrs) *'),
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter age' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _heightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Height (cm) *'),
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter height' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Weight (kg) *'),
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter weight' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Activity Level
            DropdownButtonFormField<String>(
              value: _activityLevel,
              decoration: const InputDecoration(
                labelText: 'Activity Level',
                prefixIcon: Icon(Icons.directions_run_rounded),
              ),
              items: _activityOptions.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() => _activityLevel = v!),
            ),
            const SizedBox(height: 16),

            // Goal
            DropdownButtonFormField<String>(
              value: _goal,
              decoration: const InputDecoration(
                labelText: 'Primary Goal',
                prefixIcon: Icon(Icons.track_changes_rounded),
              ),
              items: _goalOptions.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() => _goal = v!),
            ),
            const SizedBox(height: 24),

            // Calculation Results Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Metabolic Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Basal Metabolic Rate (BMR):', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text('${bmr.toStringAsFixed(0)} kcal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Daily Energy (TDEE):', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text('${tdee.toStringAsFixed(0)} kcal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recommended Target:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                        '${calculatedTarget.toStringAsFixed(0)} kcal/day',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Manual Overrides
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Manual Target Overrides', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Customize your exact daily calories, step goal, or water target', style: TextStyle(fontSize: 12)),
              value: _manualOverride,
              onChanged: (v) => setState(() => _manualOverride = v),
            ),

            if (_manualOverride) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _customCalorieCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Custom Calorie Target (kcal)',
                  prefixIcon: Icon(Icons.local_fire_department, color: Color(0xFFF97316)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customStepCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Daily Step Goal (steps)',
                  prefixIcon: Icon(Icons.directions_walk, color: Color(0xFF10B981)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customWaterCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Daily Water Goal (ml)',
                  prefixIcon: Icon(Icons.water_drop, color: Color(0xFF0284C7)),
                ),
              ),
            ],

            const SizedBox(height: 32),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _onSave,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Save Health Goals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
