import 'package:flutter/material.dart';

class StepMilestoneDialog extends StatelessWidget {
  final int milestoneSteps;

  const StepMilestoneDialog({
    super.key,
    required this.milestoneSteps,
  });

  static Future<void> show(BuildContext context, int milestone) {
    return showDialog(
      context: context,
      builder: (ctx) => StepMilestoneDialog(milestoneSteps: milestone),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFF97316),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '🔥 $milestoneSteps Steps Reached!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Amazing momentum! You\'re staying active and making steady progress toward your daily fitness goal.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Awesome! Keep Going 🚀'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
