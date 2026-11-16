import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/services/step_calculator.dart';
import '../../domain/services/step_sensor_service.dart';
import '../controllers/health_controller.dart';
import '../widgets/step_milestone_dialog.dart';

class StepCounterPage extends ConsumerStatefulWidget {
  const StepCounterPage({super.key});

  @override
  ConsumerState<StepCounterPage> createState() => _StepCounterPageState();
}

class _StepCounterPageState extends ConsumerState<StepCounterPage> {
  @override
  void initState() {
    super.initState();
    // Initialize sensor on-demand only when opening step counter
    StepSensorService.instance.initSensor();
  }

  void _showManualStepDialog(int currentSteps) {
    final ctrl = TextEditingController(text: currentSteps > 0 ? currentSteps.toString() : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Steps Manually 🚶'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'If your phone sensor is resting or unavailable, log your steps manually:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Total Steps Today',
                hintText: 'e.g. 7500',
                prefixIcon: const Icon(Icons.directions_walk),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final steps = int.tryParse(ctrl.text.trim());
              if (steps != null && steps >= 0) {
                Navigator.pop(ctx);
                ref.read(healthControllerProvider.notifier).logSteps(steps, source: 'manual');
              }
            },
            child: const Text('Save Steps'),
          ),
        ],
      ),
    );
  }

  void _showCustomizeGoalDialog(int currentGoal) {
    final goals = [3000, 5000, 7500, 10000, 12500, 15000];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Daily Step Goal 🎯'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: goals.map((g) {
            final isSelected = g == currentGoal;
            return ListTile(
              title: Text('$g steps / day', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF10B981)) : null,
              onTap: () {
                Navigator.pop(ctx);
                final profile = ref.read(healthControllerProvider).profile.copyWith(dailyStepGoal: g);
                ref.read(healthControllerProvider.notifier).updateProfile(profile);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthState = ref.watch(healthControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final steps = healthState.liveSteps;
    final goal = healthState.profile.dailyStepGoal;
    final progress = goal > 0 ? (steps / goal).clamp(0.0, 1.5) : 0.0;
    final distanceKm = StepCalculator.calculateDistanceKm(steps);
    final activeMins = StepCalculator.calculateActiveMinutes(steps);
    final caloriesBurned = StepCalculator.calculateCaloriesBurned(steps);
    final remainingSteps = goal - steps;

    // Check for celebration milestone
    if (healthState.newlyReachedMilestone != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        StepMilestoneDialog.show(context, healthState.newlyReachedMilestone!);
        ref.read(healthControllerProvider.notifier).clearMilestoneNotification();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step Counter & Activity', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Customize Step Goal',
            onPressed: () => _showCustomizeGoalDialog(goal),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Hardware Sensor Status Banner
          if (healthState.sensorStatus == StepSensorStatus.permissionDenied)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Activity recognition permission is needed for live step counting.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => StepSensorService.instance.initSensor(),
                    child: const Text('Grant'),
                  ),
                ],
              ),
            )
          else if (healthState.sensorStatus == StepSensorStatus.permissionPermanentlyDenied)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, color: Colors.red, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Permission permanently denied in system settings.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text('Settings'),
                  ),
                ],
              ),
            )
          else if (healthState.sensorStatus == StepSensorStatus.unavailable)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sensors_off_rounded, color: Colors.blueGrey, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Step sensor unavailable on this device. You can log steps manually.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Main Step Circular Display
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        strokeWidth: 16,
                        backgroundColor: const Color(0xFF10B981).withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_walk_rounded, color: Color(0xFF10B981), size: 36),
                        const SizedBox(height: 4),
                        Text(
                          steps.toString(),
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Goal: $goal steps',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    remainingSteps > 0
                        ? '$remainingSteps steps remaining to goal'
                        : '🎉 Daily Step Goal Completed!',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3 Metric Cards: Distance, Calories Burned, Active Time
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Distance',
                  value: '$distanceKm',
                  unit: 'km',
                  icon: Icons.place_rounded,
                  color: const Color(0xFF0284C7),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: 'Calories',
                  value: caloriesBurned.toStringAsFixed(0),
                  unit: 'kcal',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFF97316),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: 'Active Time',
                  value: '$activeMins',
                  unit: 'mins',
                  icon: Icons.timer_rounded,
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Manual Step Entry Action
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _showManualStepDialog(steps),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Enter Steps Manually', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Milestones Progress List
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
                const Text('Daily Step Milestones', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: StepCalculator.milestones.map((m) {
                    final isReached = steps >= m;
                    return Chip(
                      avatar: Icon(
                        isReached ? Icons.check_circle : Icons.circle_outlined,
                        size: 16,
                        color: isReached ? const Color(0xFF10B981) : Colors.grey,
                      ),
                      label: Text('$m steps'),
                      backgroundColor: isReached
                          ? const Color(0xFF10B981).withOpacity(0.12)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                      side: BorderSide(
                        color: isReached ? const Color(0xFF10B981).withOpacity(0.3) : Colors.transparent,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
