import 'package:flutter/material.dart';
import '../../../models/my_day_models.dart';
import '../../../services/focus_timer_service.dart';

/// Modal dialog for Deep Focus Mode with live timer, pause/resume, and logging
class FocusTimerDialog extends StatefulWidget {
  final MyDayTask? initialTask;

  const FocusTimerDialog({super.key, this.initialTask});

  @override
  State<FocusTimerDialog> createState() => _FocusTimerDialogState();
}

class _FocusTimerDialogState extends State<FocusTimerDialog> {
  final _focusService = FocusTimerService.instance;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!_focusService.isRunning) {
      _focusService.startFocus(
        task: widget.initialTask,
        plannedMinutes: widget.initialTask?.durationMinutes ?? 25,
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _focusService,
      builder: (context, _) {
        final isRunning = _focusService.isRunning;
        final isPaused = _focusService.isPaused;
        final isOvertime = _focusService.isOvertime;
        final categoryColor = MyDayCategoryHelper.getCategoryColor(_focusService.category);

        return Dialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          insetPadding: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.timer_rounded, color: Color(0xFF8B5CF6)),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Deep Focus Session',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Active Task Name & Category Pill
                Text(
                  _focusService.taskTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    MyDayCategoryHelper.categoryLabels[_focusService.category] ?? _focusService.category.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: categoryColor),
                  ),
                ),

                const SizedBox(height: 24),

                // Circular Timer
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: _focusService.progressFraction,
                        strokeWidth: 10,
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(isOvertime ? Colors.amber : const Color(0xFF00F2FE)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _focusService.formattedRemainingTime,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: isOvertime ? Colors.amber : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOvertime ? 'Overtime (+${_focusService.formattedElapsedTime})' : 'Elapsed: ${_focusService.formattedElapsedTime}',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Quick Add Minutes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => _focusService.addMinutes(5),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('+5 Min'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => _focusService.addMinutes(10),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('+10 Min'),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Primary Controls (Pause/Resume, Finish)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (isPaused) {
                            _focusService.resume();
                          } else {
                            _focusService.pause();
                          }
                        },
                        icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                        label: Text(isPaused ? 'Resume' : 'Pause'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPaused ? Colors.green : Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _focusService.finishAndSave(markTaskCompleted: true);
                          if (context.mounted) {
                            Navigator.pop(context, true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🎉 Focus session logged and task marked complete!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Finish'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
