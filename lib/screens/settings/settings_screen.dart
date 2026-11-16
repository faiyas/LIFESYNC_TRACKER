import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/app_provider.dart';
import '../../services/app_notification_scheduler.dart';
import '../../services/notification_service.dart';
import '../../services/google_sheets_backup_service.dart';
import '../../services/apps_script_template.dart';
import '../../features/payment_scanner/screens/auto_payment_dashboard_screen.dart';
import '../../features/payment_scanner/services/auto_payment_manager.dart';
import '../../features/ai_assistant/screens/ai_assistant_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  bool _isNotificationGranted = false;
  bool _isCheckingPermissions = true;

  // Google Sheets state
  String? _sheetsUrl;
  bool _autoSyncEnabled = true;
  String? _lastSyncTime;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotificationStatus();
    _loadGoogleSheetsSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationStatus();
      _loadGoogleSheetsSettings();
    }
  }

  Future<void> _checkNotificationStatus() async {
    final granted = await NotificationService.instance.arePermissionsGranted();
    final notifStatus = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _isNotificationGranted = granted || notifStatus.isGranted;
        _isCheckingPermissions = false;
      });
    }
  }

  Future<void> _loadGoogleSheetsSettings() async {
    final url = await GoogleSheetsBackupService.instance.getWebAppUrl();
    final auto = await GoogleSheetsBackupService.instance.isAutoSyncEnabled();
    final lastSync = await GoogleSheetsBackupService.instance.getLastSyncTime();
    if (mounted) {
      setState(() {
        _sheetsUrl = url;
        _autoSyncEnabled = auto;
        _lastSyncTime = lastSync;
      });
    }
  }

  String _formatSyncTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Never backed up';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$date at $hour:$minute $ampm';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    AppProvider? provider;
    try {
      provider = context.watch<AppProvider>();
    } catch (_) {
      provider = null;
    }

    final currentThemeMode = provider?.themeMode ?? AppThemeMode.dark;
    final isPinActive = provider?.pinCode != null && provider!.pinCode!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings ⚙️'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [Colors.indigo.shade500, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: const Icon(Icons.settings_suggest, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preferences & Cloud Sync',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Google Sheets backup, notifications & security',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Google Sheets Cloud Backup Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Google Sheets Cloud Backup 📊', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
              InkWell(
                onTap: _showAppsScriptGuideModal,
                child: const Text('View Script / Guide 📋', style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.table_chart_rounded, color: Colors.green, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Google Sheets Live Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(
                              'Last Synced: ${_formatSyncTime(_lastSyncTime)}',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _sheetsUrl != null && _sheetsUrl!.isNotEmpty
                              ? Colors.green.withOpacity(0.15)
                              : Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _sheetsUrl != null && _sheetsUrl!.isNotEmpty ? 'Configured' : 'Not Set',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _sheetsUrl != null && _sheetsUrl!.isNotEmpty ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // Web App URL Tile
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Apps Script Web App URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      _sheetsUrl != null && _sheetsUrl!.isNotEmpty
                          ? _sheetsUrl!
                          : 'Tap here to enter your Google Apps Script URL',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _sheetsUrl != null && _sheetsUrl!.isNotEmpty
                            ? (isDark ? Colors.white70 : Colors.black87)
                            : Colors.blue,
                        fontStyle: _sheetsUrl != null && _sheetsUrl!.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit, size: 14),
                      label: Text(_sheetsUrl != null && _sheetsUrl!.isNotEmpty ? 'Edit' : 'Set URL'),
                      onPressed: _showUrlConfigDialog,
                    ),
                    onTap: _showUrlConfigDialog,
                  ),
                  const Divider(height: 1),
                  // Auto-Sync Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Auto-Sync After Each Change', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Pushes updates to Google Sheets in real-time'),
                    value: _autoSyncEnabled,
                    onChanged: (val) async {
                      await GoogleSheetsBackupService.instance.setAutoSyncEnabled(val);
                      setState(() => _autoSyncEnabled = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  // Test Connection Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (_isBackingUp || _isRestoring) ? null : _testGoogleSheetsConnection,
                      icon: const Icon(Icons.wifi_tethering_rounded, size: 18, color: Color(0xFF0284C7)),
                      label: const Text(
                        'Test Google Sheets Connection',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Backup Now Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (_isBackingUp || _isRestoring) ? null : _handleManualBackup,
                      icon: _isBackingUp
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.cloud_upload_rounded, size: 20),
                      label: Text(
                        _isBackingUp ? 'Syncing to Google Sheets...' : 'Backup All Tables to Google Sheets Now',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Restore From Cloud Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.green.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (_isBackingUp || _isRestoring) ? null : _handleCloudRestore,
                      icon: _isRestoring
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2))
                          : Icon(Icons.cloud_download_rounded, size: 20, color: Colors.green.shade700),
                      label: Text(
                        _isRestoring ? 'Pulling from Google Sheets...' : 'Pull & Restore from Google Sheets',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Automated Payment Tracking Section
          const Text('Automated Payment Tracking ⚡', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 24),
              ),
              title: const Text('Auto-Fetch Payments', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Bank SMS, Live UPI Notifications, and Screenshot Auto-Watcher with zero duplicates.'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AutoPaymentDashboardScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 24),
              ),
              title: const Text('AI Voice Assistant (NVIDIA NIM)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Talk with LLM, voice replies, auto-set reminders, log expenses & generate free images.'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Security & Notification Section
          const Text('Security & Push Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: Colors.indigo),
                  title: const Text('Security PIN Lock', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(isPinActive ? 'PIN protection active' : 'No security PIN set'),
                  trailing: Switch(
                    value: isPinActive,
                    onChanged: (enabled) {
                      if (enabled) {
                        _setPinDialog(context, provider);
                      } else {
                        provider?.setPinCode(null);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined, color: Colors.amber),
                  title: const Text('Notification Permission', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Required for scheduled alerts and daily summaries'),
                  trailing: _isCheckingPermissions
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : _isNotificationGranted
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green.withOpacity(0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Granted ✅',
                                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                final notifGranted = await NotificationService.instance.requestPermissions();
                                final status = await Permission.notification.request();
                                try {
                                  await Permission.scheduleExactAlarm.request();
                                } catch (_) {}

                                await _checkNotificationStatus();

                                if (context.mounted) {
                                  final isOk = _isNotificationGranted || status.isGranted || notifGranted;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isOk
                                            ? '✅ Notification Permission Granted & Exact Alarms Configured!'
                                            : '⚠️ Notification Permission: ${status.name.toUpperCase()}',
                                      ),
                                      backgroundColor: isOk ? Colors.green : Colors.orange,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Grant'),
                            ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Automated Push Notifications Cards
          const Text('Automated Push Schedules', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                // 11:00 PM Financial Summary
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.nightlight_round, color: Colors.purple),
                  ),
                  title: const Text('Daily 11:00 PM Financial Summary', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Push summary of Today Spent, Today Income & Overall Balance'),
                  trailing: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    onPressed: () async {
                      await AppNotificationScheduler.instance.sendInstantFinancialSummaryNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🌙 Sent instant 11:00 PM Financial Summary Push Notification!'),
                            backgroundColor: Colors.purple,
                          ),
                        );
                      }
                    },
                    child: const Text('Test Push', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const Divider(height: 1),
                // 6-Hour Pending Task Reminders
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.alarm_on_rounded, color: Colors.blue),
                  ),
                  title: const Text('6-Hour Pending Tasks Reminder', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Every 6 hours pushes reminder if pending tasks remain (6AM, 12PM, 6PM, 12AM)'),
                  trailing: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    onPressed: () async {
                      await AppNotificationScheduler.instance.sendInstantTaskReminderNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📋 Sent instant 6-Hour Pending Task Push Reminder!'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      }
                    },
                    child: const Text('Test Push', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Health & Fitness Settings Section
          const Text('Health & Fitness', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.fitness_center_rounded, color: Color(0xFF0284C7)),
                  title: const Text('Your Health Goals', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Calorie target, BMR, TDEE, height, weight & activity'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    context.push('/health_profile');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.directions_walk_rounded, color: Color(0xFF10B981)),
                  title: const Text('Step Counter & Sensors', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Step goals, hardware pedometer sensor status'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    context.push('/step_counter');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Appearance Section
          const Text('Appearance & Theme', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                RadioListTile<AppThemeMode>(
                  secondary: const Icon(Icons.dark_mode_outlined, color: Colors.indigo),
                  title: const Text('Dark Mode (Default)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Sleek dark luxury color palette'),
                  value: AppThemeMode.dark,
                  groupValue: currentThemeMode,
                  onChanged: (val) {
                    if (val != null) provider?.setThemeMode(val);
                  },
                ),
                const Divider(height: 1),
                RadioListTile<AppThemeMode>(
                  secondary: const Icon(Icons.light_mode_outlined, color: Colors.amber),
                  title: const Text('Light Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Clean high-contrast daytime interface'),
                  value: AppThemeMode.light,
                  groupValue: currentThemeMode,
                  onChanged: (val) {
                    if (val != null) provider?.setThemeMode(val);
                  },
                ),
                const Divider(height: 1),
                RadioListTile<AppThemeMode>(
                  secondary: const Icon(Icons.contrast_outlined, color: Colors.teal),
                  title: const Text('High Contrast', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Maximum accessibility readability'),
                  value: AppThemeMode.highContrast,
                  groupValue: currentThemeMode,
                  onChanged: (val) {
                    if (val != null) provider?.setThemeMode(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // System Info & Storage Section
          const Text('System & Storage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.teal),
                  title: Text('LifeSync Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Version 2.0.0 (Flutter Edition • Offline First SQLite + Google Sheets Sync)'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined, color: Colors.redAccent),
                  title: const Text('Clear Temporary Storage Cache', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Free up temporary image scan cache'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Temporary cache storage cleared successfully!'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUrlConfigDialog() {
    final controller = TextEditingController(text: _sheetsUrl ?? '');
    bool isTesting = false;
    String? testResult;
    bool? testSuccess;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.table_chart_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text('Apps Script Web App URL', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste your Google Apps Script Web App URL below (e.g. https://script.google.com/macros/s/.../exec):',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'https://script.google.com/...',
                    prefixIcon: const Icon(Icons.link),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (testResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: testSuccess == true ? Colors.green.withAlpha(38) : Colors.redAccent.withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: testSuccess == true ? Colors.green : Colors.redAccent),
                    ),
                    child: Text(
                      testResult!,
                      style: TextStyle(
                        fontSize: 12,
                        color: testSuccess == true ? Colors.green : Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: isTesting
                  ? null
                  : () async {
                      setDialogState(() {
                        isTesting = true;
                        testResult = 'Testing connection... ⏳';
                        testSuccess = null;
                      });
                      final res = await GoogleSheetsBackupService.instance.testConnection(controller.text.trim());
                      setDialogState(() {
                        isTesting = false;
                        testSuccess = res['success'] == true;
                        testResult = res['message'] as String? ?? '';
                      });
                    },
              child: isTesting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Test Connection'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await GoogleSheetsBackupService.instance.setWebAppUrl(controller.text.trim());
                await _loadGoogleSheetsSettings();
                if (mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Google Apps Script URL saved successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Save URL'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testGoogleSheetsConnection() async {
    if (_sheetsUrl == null || _sheetsUrl!.isEmpty) {
      _showUrlConfigDialog();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing Google Sheets connection... ⏳'), duration: Duration(seconds: 2)),
    );

    final res = await GoogleSheetsBackupService.instance.testConnection(_sheetsUrl);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? ''),
          backgroundColor: res['success'] == true ? Colors.green : Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleManualBackup() async {
    if (_sheetsUrl == null || _sheetsUrl!.isEmpty) {
      _showUrlConfigDialog();
      return;
    }

    setState(() => _isBackingUp = true);
    final result = await GoogleSheetsBackupService.instance.backupNow();
    await _loadGoogleSheetsSettings();
    setState(() => _isBackingUp = false);

    if (mounted) {
      final success = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String? ?? 'Backup completed'),
          backgroundColor: success ? Colors.green : Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleCloudRestore() async {
    if (_sheetsUrl == null || _sheetsUrl!.isEmpty) {
      _showUrlConfigDialog();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Data from Google Sheets? 📥'),
        content: const Text(
          'This will pull all tables and records from your Google Sheets spreadsheet and merge/restore them into your offline SQLite database.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Now'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRestoring = true);
    final result = await GoogleSheetsBackupService.instance.restoreFromCloud();
    await _loadGoogleSheetsSettings();
    setState(() => _isRestoring = false);

    if (mounted) {
      final success = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String? ?? 'Restore completed'),
          backgroundColor: success ? Colors.green : Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
      if (success) {
        try {
          Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
        } catch (_) {}
      }
    }
  }

  void _showAppsScriptGuideModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.code_rounded, color: Color(0xFF0284C7)),
                      SizedBox(width: 8),
                      Text('Apps Script Setup Guide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Follow these simple steps to connect LifeSync Tracker to your Google Spreadsheet without any backend server:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              _buildStepItem('1', 'Create a new Google Sheet at https://sheets.new'),
              _buildStepItem('2', 'Click on Extensions > Apps Script in Google Sheets top menu.'),
              _buildStepItem('3', 'Delete any code in Code.gs, paste the script below, and save.'),
              _buildStepItem('4', 'Click Deploy > New deployment > Select "Web app".'),
              _buildStepItem('5', 'Set "Execute as: Me" and "Who has access: Anyone". Click Deploy.'),
              _buildStepItem('6', 'Copy the Web app URL and paste it in Settings > Google Sheets URL.'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Google Apps Script Code (Code.gs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Script'),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: AppsScriptTemplate.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Apps Script Code copied to clipboard!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const SelectableText(
                  AppsScriptTemplate.code,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.lightGreenAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFF0284C7),
            child: Text(number, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _setPinDialog(BuildContext context, AppProvider? provider) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.security, color: Colors.indigo),
            ),
            const SizedBox(width: 12),
            const Text('Set 4-Digit PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Enter 4-Digit PIN',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.lock),
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (pinController.text.length == 4) {
                provider?.setPinCode(pinController.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Security PIN set successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Save PIN', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
