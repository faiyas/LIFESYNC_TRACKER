import 'package:flutter/material.dart';

class WaterIntakeCard extends StatelessWidget {
  final int totalWaterMl;
  final int waterGoalMl;
  final Function(int ml) onAddWater;
  final VoidCallback onUndoWater;
  final VoidCallback? onCustomWater;

  const WaterIntakeCard({
    super.key,
    required this.totalWaterMl,
    required this.waterGoalMl,
    required this.onAddWater,
    required this.onUndoWater,
    this.onCustomWater,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = waterGoalMl > 0 ? (totalWaterMl / waterGoalMl).clamp(0.0, 1.0) : 0.0;
    const waterColor = Color(0xFF0284C7); // Cyan / Blue

    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: waterColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.water_drop_rounded, color: waterColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Water Intake',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Stay refreshed and hydrated',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (totalWaterMl > 0)
                TextButton.icon(
                  onPressed: onUndoWater,
                  icon: const Icon(Icons.undo_rounded, size: 14, color: Colors.redAccent),
                  label: const Text('Undo', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Numerical stats & progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${(totalWaterMl / 1000).toStringAsFixed(2)} ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    TextSpan(
                      text: '/ ${(waterGoalMl / 1000).toStringAsFixed(1)} L',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: waterColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Linear progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: waterColor.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(waterColor),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 16),

          // Quick buttons
          Row(
            children: [
              _buildQuickButton(context, '+250 ml', () => onAddWater(250)),
              const SizedBox(width: 8),
              _buildQuickButton(context, '+500 ml', () => onAddWater(500)),
              const SizedBox(width: 8),
              _buildQuickButton(context, '+750 ml', () => onAddWater(750)),
              const SizedBox(width: 8),
              _buildQuickButton(
                context,
                'Custom',
                onCustomWater ?? () => _showCustomWaterDialog(context),
                isOutlined: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickButton(
    BuildContext context,
    String label,
    VoidCallback onTap, {
    bool isOutlined = false,
  }) {
    return Expanded(
      child: SizedBox(
        height: 38,
        child: isOutlined
            ? OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                ),
              )
            : ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: const Color(0xFF0284C7).withOpacity(0.12),
                  foregroundColor: const Color(0xFF0284C7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }

  void _showCustomWaterDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Water Intake 💧'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Amount (ml)',
            hintText: 'e.g. 350',
            suffixText: 'ml',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(ctrl.text.trim());
              if (amount != null && amount > 0) {
                Navigator.pop(ctx);
                onAddWater(amount);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
