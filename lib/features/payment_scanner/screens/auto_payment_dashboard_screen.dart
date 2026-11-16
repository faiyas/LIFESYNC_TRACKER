import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/detected_payment.dart';
import '../services/auto_payment_manager.dart';

class AutoPaymentDashboardScreen extends StatefulWidget {
  const AutoPaymentDashboardScreen({super.key});

  @override
  State<AutoPaymentDashboardScreen> createState() => _AutoPaymentDashboardScreenState();
}

class _AutoPaymentDashboardScreenState extends State<AutoPaymentDashboardScreen> {
  final _manager = AutoPaymentManager.instance;
  bool _smsPermissionGranted = false;
  bool _notifListenerEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _manager.addListener(_onManagerUpdate);
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerUpdate);
    super.dispose();
  }

  void _onManagerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _checkPermissions() async {
    final sms = await _manager.checkSmsPermission();
    final notif = await _manager.isNotificationListenerEnabled();
    if (mounted) {
      setState(() {
        _smsPermissionGranted = sms;
        _notifListenerEnabled = notif;
      });
    }
  }

  Future<void> _requestSms() async {
    final res = await _manager.requestSmsPermission();
    if (mounted) {
      setState(() => _smsPermissionGranted = res);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res ? '✅ SMS Permission Granted!' : '❌ SMS Permission Denied'),
          backgroundColor: res ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _openNotifSettings() async {
    await _manager.openNotificationListenerSettings();
  }

  Future<void> _runManualSync() async {
    final count = await _manager.syncAllChannelsNow();
    await _checkPermissions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? '✅ Synced and processed $count new payment transaction(s)!'
              : '✅ Sync complete: All channels are up to date. No new unlogged payments.'),
          backgroundColor: Colors.indigo,
        ),
      );
    }
  }

  void _showSimulationDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.science_rounded, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text('Failover & Dedup Test Simulator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Test the multi-channel failover and verify that duplicates are recognized and safely blocked.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Divider(height: 24),

              // Step 1: Simulate UPI Notification
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.notifications_active_rounded, color: Colors.blue),
                ),
                title: const Text('1. Simulate UPI Notification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Google Pay: Paid ₹250.00 to Chai Point (Txn: UPI987654)'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _manager.simulateNotification(
                      title: 'Google Pay',
                      body: 'Payment Successful. Paid ₹250.00 to Chai Point. UPI Ref: UPI987654',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Simulated UPI notification processed!'), backgroundColor: Colors.blue),
                      );
                    }
                  },
                  child: const Text('Send'),
                ),
              ),
              const Divider(height: 16),

              // Step 2: Simulate Bank SMS for exact same transaction
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.sms_rounded, color: Colors.green),
                ),
                title: const Text('2. Simulate Bank SMS for Same Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('HDFC SMS: INR 250.00 debited to Chai Point (Tests duplicate blocking & enrichment)'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _manager.simulateSms(
                      sender: 'HDFCBK',
                      body: 'Dear Customer, Rs 250.00 debited from A/C XX9999 on 13-Nov-26 to CHAI POINT UPI Ref: UPI987654',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bank SMS simulated! Deduplication Engine evaluated.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Send'),
                ),
              ),
              const Divider(height: 16),

              // Step 3: Simulate New Different Payment
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.teal),
                ),
                title: const Text('3. Simulate Distinct Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('PhonePe: Paid ₹480.00 to Swiggy'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _manager.simulateNotification(
                      title: 'PhonePe',
                      body: 'Transaction Successful. Paid ₹480.00 to Swiggy India. UTR: SWIGGY8888',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New transaction simulated and saved!'), backgroundColor: Colors.teal),
                      );
                    }
                  },
                  child: const Text('Send'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Payment Tracking ⚡'),
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Simulate & Test Failover',
            onPressed: _showSimulationDialog,
          ),
          IconButton(
            icon: _manager.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: 'Sync All Channels Now',
            onPressed: _manager.isSyncing ? null : _runManualSync,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _checkPermissions();
          await _manager.syncAllChannelsNow();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Master Switch Banner
            _buildMasterToggleCard(isDark),
            const SizedBox(height: 16),

            // Failover Channels Status Card
            _buildChannelsCard(isDark),
            const SizedBox(height: 16),

            // Deduplication Engine Card
            _buildDedupMetricCard(isDark),
            const SizedBox(height: 16),

            // Mode Settings (Auto-Save vs Review Queue)
            _buildModeSettingsCard(isDark),
            const SizedBox(height: 20),

            // Review Queue Section (if items exist)
            if (_manager.pendingReviewQueue.isNotEmpty) ...[
              _buildReviewQueueHeader(),
              const SizedBox(height: 8),
              ..._manager.pendingReviewQueue.map((p) => _buildReviewQueueItem(p, isDark)),
              const SizedBox(height: 20),
            ],

            // Live Activity Feed
            _buildActivityFeedHeader(),
            const SizedBox(height: 8),
            if (_manager.recentActivity.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.query_builder_rounded, size: 40, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No Automated Payments Captured Yet',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Once you receive a bank SMS, UPI notification, or take a payment screenshot, it will appear here automatically with no duplicates!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ..._manager.recentActivity.map((event) => _buildActivityItem(event, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterToggleCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _manager.isAutoTrackingEnabled
              ? [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)]
              : [Colors.grey.shade800, Colors.grey.shade700],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_manager.isAutoTrackingEnabled ? Colors.blue : Colors.black).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _manager.isAutoTrackingEnabled ? Icons.bolt_rounded : Icons.power_settings_new_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Automated Payments',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _manager.isAutoTrackingEnabled
                      ? 'Listening to SMS, UPI notifications & Screenshots'
                      : 'Automatic tracking is paused',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _manager.isAutoTrackingEnabled,
            activeColor: Colors.white,
            activeTrackColor: Colors.lightGreenAccent.shade400,
            onChanged: (val) => _manager.setAutoTrackingEnabled(val),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelsCard(bool isDark) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.alt_route_rounded, color: Colors.blueAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Failover Ingestion Channels',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'If one source fails or is delayed, the next one automatically catches the payment.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Divider(height: 24),

            // Channel 1: Notifications
            _buildChannelRow(
              icon: Icons.notifications_active_outlined,
              title: 'Live UPI Push Notifications',
              subtitle: 'Listens to GPay, PhonePe, Paytm, CRED in real-time',
              isEnabled: _manager.isNotificationEnabled,
              isPermitted: _notifListenerEnabled,
              permActionText: 'Enable Access',
              onPermAction: _openNotifSettings,
              onToggle: (v) => _manager.setNotificationEnabled(v),
            ),
            const Divider(height: 20),

            // Channel 2: Screenshot Watcher
            _buildChannelRow(
              icon: Icons.screenshot_outlined,
              title: 'Screenshot Folder Auto-Watcher',
              subtitle: 'Monitors Pictures/Screenshots for receipt images',
              isEnabled: _manager.isScreenshotWatcherEnabled,
              isPermitted: true,
              onToggle: (v) => _manager.setScreenshotWatcherEnabled(v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required bool isPermitted,
    String? permActionText,
    VoidCallback? onPermAction,
    required ValueChanged<bool> onToggle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: isEnabled && isPermitted ? Colors.teal : Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isEnabled && isPermitted)
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      !isEnabled
                          ? 'Off'
                          : isPermitted
                              ? 'Active'
                              : 'Needs Access',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: (isEnabled && isPermitted) ? Colors.green : Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              if (isEnabled && !isPermitted && onPermAction != null && permActionText != null) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: onPermAction,
                  child: Text(
                    '👉 $permActionText',
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: isEnabled,
          onChanged: onToggle,
        ),
      ],
    );
  }

  Widget _buildDedupMetricCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.indigo, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Zero-Duplicate Guarantee',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Cross-channel matching & Txn ID fingerprints prevent duplicate entries.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_manager.duplicatesPrevented}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const Text('Blocked', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSettingsCard(bool isDark) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Capture Workflow Mode',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            RadioListTile<bool>(
              value: true,
              groupValue: _manager.isAutoSaveDirectly,
              title: const Text('Direct Auto-Save (Recommended)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Logs expense immediately & alerts you with a notification. Zero manual taps.', style: TextStyle(fontSize: 11)),
              onChanged: (v) {
                if (v != null) _manager.setAutoSaveDirectly(v);
              },
            ),
            RadioListTile<bool>(
              value: false,
              groupValue: _manager.isAutoSaveDirectly,
              title: const Text('Review Queue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Stores transactions in a pending queue so you can review before confirming.', style: TextStyle(fontSize: 11)),
              onChanged: (v) {
                if (v != null) _manager.setAutoSaveDirectly(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewQueueHeader() {
    return Row(
      children: [
        const Icon(Icons.pending_actions_rounded, color: Colors.amber, size: 20),
        const SizedBox(width: 8),
        Text(
          'Pending Review (${_manager.pendingReviewQueue.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildReviewQueueItem(DetectedPayment payment, bool isDark) {
    final amountStr = '₹${(payment.amount ?? 0).toStringAsFixed(2)}';
    final merchant = payment.merchant ?? 'Payment';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: payment.isIncome ? Colors.teal.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                payment.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: payment.isIncome ? Colors.teal : Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(merchant, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(
                    '${payment.suggestedCategory} • ${payment.paymentMethod ?? "UPI"}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(
              amountStr,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: payment.isIncome ? Colors.teal : Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
              tooltip: 'Confirm',
              onPressed: () => _manager.confirmReviewPayment(payment),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.grey),
              tooltip: 'Discard',
              onPressed: () => _manager.discardReviewPayment(payment),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityFeedHeader() {
    return const Row(
      children: [
        Icon(Icons.history_rounded, size: 20),
        SizedBox(width: 8),
        Text(
          'Live Automated Activity Feed',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildActivityItem(AutoCapturedEvent event, bool isDark) {
    final payment = event.payment;
    final amountStr = '₹${(payment.amount ?? 0).toStringAsFixed(2)}';
    final merchant = payment.merchant ?? 'Payment';
    final timeStr = DateFormat('hh:mm a').format(event.timestamp);

    Color badgeColor;
    String badgeText;
    if (event.wasDuplicate) {
      badgeColor = Colors.amber.shade800;
      badgeText = 'DUPLICATE PREVENTED';
    } else {
      switch (event.source.toLowerCase()) {
        case 'sms':
          badgeColor = Colors.green;
          badgeText = 'BANK SMS';
          break;
        case 'notification':
          badgeColor = Colors.blueAccent;
          badgeText = 'UPI NOTIFICATION';
          break;
        case 'screenshot':
          badgeColor = Colors.purpleAccent;
          badgeText = 'SCREENSHOT';
          break;
        default:
          badgeColor = Colors.teal;
          badgeText = event.source.toUpperCase();
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                event.wasDuplicate
                    ? Icons.filter_alt_off_outlined
                    : payment.isIncome
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                color: badgeColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          merchant,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        amountStr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: event.wasDuplicate ? Colors.grey : (payment.isIncome ? Colors.teal : null),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                        tooltip: 'Delete transaction',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('Delete Transaction?'),
                              content: Text('Do you want to permanently remove this ${payment.isIncome ? "income" : "expense"} of $amountStr?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _manager.deleteCapturedEvent(event);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Transaction deleted.'), duration: Duration(seconds: 2)),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.statusMessage,
                    style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
