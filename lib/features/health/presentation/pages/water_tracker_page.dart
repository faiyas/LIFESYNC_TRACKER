import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/health_controller.dart';
import '../widgets/water_intake_card.dart';

class WaterTrackerPage extends ConsumerWidget {
  const WaterTrackerPage({super.key});

  void _showCustomizeGoalDialog(BuildContext context, WidgetRef ref, int currentGoal) {
    final ctrl = TextEditingController(text: currentGoal.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Daily Water Goal 💧'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Goal in ml',
            hintText: 'e.g. 2500',
            suffixText: 'ml',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newGoal = int.tryParse(ctrl.text.trim());
              if (newGoal != null && newGoal > 0) {
                Navigator.pop(ctx);
                final profile = ref.read(healthControllerProvider).profile.copyWith(dailyWaterGoal: newGoal);
                ref.read(healthControllerProvider.notifier).updateProfile(profile);
              }
            },
            child: const Text('Save Goal'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(healthControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final waterLogs = healthState.waterLogs.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Intake Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Customize Water Goal',
            onPressed: () => _showCustomizeGoalDialog(context, ref, healthState.profile.dailyWaterGoal),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          WaterIntakeCard(
            totalWaterMl: healthState.totalWaterMl,
            waterGoalMl: healthState.profile.dailyWaterGoal,
            onAddWater: (ml) => ref.read(healthControllerProvider.notifier).logWater(ml),
            onUndoWater: () => ref.read(healthControllerProvider.notifier).undoWater(),
          ),
          const SizedBox(height: 16),

          Text(
            'Today\'s Hydration Log (${waterLogs.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (waterLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.water_drop_outlined, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No water entries logged today yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: waterLogs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final log = waterLogs[index];
                DateTime logTime;
                try {
                  logTime = DateTime.parse(log.loggedAt);
                } catch (_) {
                  logTime = DateTime.now();
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '+${log.amountMl} ml',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              DateFormat('hh:mm a').format(logTime),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
