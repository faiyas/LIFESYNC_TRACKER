import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifesync_ui_components.dart';
import '../finance/expenses_screen.dart';
import '../finance/income_screen.dart';
import '../finance/budget_screen.dart';
import '../finance/savings_screen.dart';
import '../finance/net_worth_screen.dart';
import '../productivity/todos_screen.dart';
import '../my_day/my_day_screen.dart';
import '../settings/settings_screen.dart';
import '../business/customers_screen.dart';
import '../lifestyle/bills_screen.dart';
import '../search/global_search_screen.dart';
import '../analytics/analytics_screen.dart';
import '../navigation/navigation_screen.dart';
import '../../services/app_notification_scheduler.dart';
import '../../services/app_time_service.dart';
import '../../services/google_sheets_backup_service.dart';
import '../../features/payment_scanner/screens/payment_scanner_screen.dart';
import '../../features/health/presentation/widgets/home_health_summary_card.dart';
import '../../features/ai_assistant/screens/ai_assistant_screen.dart';

class RecentActivityItem {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final String date;
  final String type; // 'income', 'expense', 'trip_expense', 'loan', 'customer'

  const RecentActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.type,
  });
}

enum DashboardDateFilterType {
  day,
  month,
  year,
  all,
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Period Filtering (Default: Month-wise)
  DashboardDateFilterType _filterType = DashboardDateFilterType.month;
  DateTime _selectedDate = DateTime.now();

  // Financial Totals
  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;
  double _unpaidBills = 0.0;
  double _savedMoney = 0.0;
  double _customerReceivables = 0.0;

  // Today specific metrics
  int _todayTasksTotal = 0;
  int _todayTasksCompleted = 0;
  int _scheduledMinutesToday = 0;

  // Wallet Balances (UPI & Cash)
  double _upiIncome = 0.0;
  double _upiExpenses = 0.0;
  double _cashIncome = 0.0;
  double _cashExpenses = 0.0;
  double get _upiBalance => _upiIncome - _upiExpenses;
  double get _cashBalance => _cashIncome - _cashExpenses;

  // Chart Data
  Map<String, double> _categoryBreakdown = {};
  int _activeChartIndex = 0; // 0: Cashflow Bar Chart, 1: Category Donut Chart

  List<RecentActivityItem> _recentActivity = [];
  int _activityPage = 1;
  static const int _activityPageSize = 5;
  bool _isLoading = true;
  int _lastDataVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadDashboardData();
      }
    } catch (_) {}
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    double totalInc = 0.0;
    double genExp = 0.0;
    double tripExp = 0.0;
    double unpaidBills = 0.0;
    double savingsAmt = 0.0;
    double receivablesAmt = 0.0;
    double upiInc = 0.0;
    double cashInc = 0.0;
    double upiExp = 0.0;
    double cashExp = 0.0;
    int tasksTotal = 0;
    int tasksDone = 0;
    int schedMins = 0;
    final catBreakdown = <String, double>{};
    final List<RecentActivityItem> activity = [];

    String? filterPrefix;
    switch (_filterType) {
      case DashboardDateFilterType.day:
        filterPrefix = DateFormat('yyyy-MM-dd').format(_selectedDate);
        break;
      case DashboardDateFilterType.month:
        filterPrefix = DateFormat('yyyy-MM').format(_selectedDate);
        break;
      case DashboardDateFilterType.year:
        filterPrefix = DateFormat('yyyy').format(_selectedDate);
        break;
      case DashboardDateFilterType.all:
        filterPrefix = null;
        break;
    }

    try {
      final db = await AppDatabase.instance.database;

      // 1. Income (Overall in period & Today)
      try {
        final incWhere = filterPrefix != null ? "WHERE date LIKE '$filterPrefix%'" : "";
        final incQuery = await db.rawQuery('SELECT SUM(amount) as total FROM income $incWhere');
        totalInc = (incQuery.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        debugPrint('Dashboard load income error: $e');
      }

      // 1b. UPI & Cash income in period
      try {
        final upiIncWhere = filterPrefix != null
            ? "WHERE LOWER(TRIM(paymentMethod)) != 'cash' AND date LIKE '$filterPrefix%'"
            : "WHERE LOWER(TRIM(paymentMethod)) != 'cash'";
        final upiIncQ = await db.rawQuery("SELECT SUM(amount) as total FROM income $upiIncWhere");
        upiInc = (upiIncQ.first['total'] as num?)?.toDouble() ?? 0.0;

        final cashIncWhere = filterPrefix != null
            ? "WHERE LOWER(TRIM(paymentMethod)) = 'cash' AND date LIKE '$filterPrefix%'"
            : "WHERE LOWER(TRIM(paymentMethod)) = 'cash'";
        final cashIncQ = await db.rawQuery("SELECT SUM(amount) as total FROM income $cashIncWhere");
        cashInc = (cashIncQ.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        debugPrint('Dashboard load wallet income error: $e');
      }

      // 2. Expenses (Overall in period & Today)
      try {
        final expWhere = filterPrefix != null ? "WHERE date LIKE '$filterPrefix%'" : "";
        final expQuery = await db.rawQuery('SELECT SUM(amount) as total FROM expenses $expWhere');
        genExp = (expQuery.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        debugPrint('Dashboard load expenses error: $e');
      }

      // 2b. UPI & Cash expenses in period
      try {
        final upiExpWhere = filterPrefix != null
            ? "WHERE LOWER(TRIM(paymentMethod)) != 'cash' AND date LIKE '$filterPrefix%'"
            : "WHERE LOWER(TRIM(paymentMethod)) != 'cash'";
        final upiExpQ = await db.rawQuery("SELECT SUM(amount) as total FROM expenses $upiExpWhere");
        upiExp = (upiExpQ.first['total'] as num?)?.toDouble() ?? 0.0;

        final cashExpWhere = filterPrefix != null
            ? "WHERE LOWER(TRIM(paymentMethod)) = 'cash' AND date LIKE '$filterPrefix%'"
            : "WHERE LOWER(TRIM(paymentMethod)) = 'cash'";
        final cashExpQ = await db.rawQuery("SELECT SUM(amount) as total FROM expenses $cashExpWhere");
        cashExp = (cashExpQ.first['total'] as num?)?.toDouble() ?? 0.0;

        try {
          final tripUpiWhere = filterPrefix != null
              ? "WHERE LOWER(TRIM(paymentMethod)) != 'cash' AND date LIKE '$filterPrefix%'"
              : "WHERE LOWER(TRIM(paymentMethod)) != 'cash'";
          final tripUpiQ = await db.rawQuery("SELECT SUM(amount) as total FROM trip_expenses $tripUpiWhere");
          upiExp += (tripUpiQ.first['total'] as num?)?.toDouble() ?? 0.0;

          final tripCashWhere = filterPrefix != null
              ? "WHERE LOWER(TRIM(paymentMethod)) = 'cash' AND date LIKE '$filterPrefix%'"
              : "WHERE LOWER(TRIM(paymentMethod)) = 'cash'";
          final tripCashQ = await db.rawQuery("SELECT SUM(amount) as total FROM trip_expenses $tripCashWhere");
          cashExp += (tripCashQ.first['total'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {}
      } catch (e) {
        debugPrint('Dashboard load wallet expenses error: $e');
      }

      // 3. Trip Expenses in period
      try {
        final tripWhere = filterPrefix != null ? "WHERE date LIKE '$filterPrefix%'" : "";
        final tripExpQuery = await db.rawQuery('SELECT SUM(amount) as total FROM trip_expenses $tripWhere');
        tripExp = (tripExpQuery.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        debugPrint('Dashboard load trip expenses error: $e');
      }

      // 4. Unpaid Bills in period (fallback to total unpaid if zero)
      try {
        final billsWhere = filterPrefix != null
            ? "WHERE isPaid = 0 AND dueDate LIKE '$filterPrefix%'"
            : "WHERE isPaid = 0";
        final billsQuery = await db.rawQuery('SELECT SUM(amount) as total FROM bills $billsWhere');
        unpaidBills = (billsQuery.first['total'] as num?)?.toDouble() ?? 0.0;
        if (unpaidBills == 0.0 && filterPrefix != null) {
          final allBills = await db.rawQuery('SELECT SUM(amount) as total FROM bills WHERE isPaid = 0');
          unpaidBills = (allBills.first['total'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (e) {
        debugPrint('Dashboard load bills error: $e');
      }

      // 6. Savings
      try {
        final s1 = await db.rawQuery('SELECT SUM(savedAmount) as total FROM savings');
        savingsAmt += (s1.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}
      try {
        final s2 = await db.rawQuery('SELECT SUM(currentAmount) as total FROM savings_goals');
        savingsAmt += (s2.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}

      // 7. Customer Receivables
      try {
        final p1 = await db.rawQuery('SELECT SUM(remainingAmount) as total FROM pending_payments WHERE status != "paid"');
        receivablesAmt += (p1.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}
      try {
        final p2 = await db.rawQuery('SELECT SUM(pendingAmount) as total FROM customer_jobs WHERE status != "completed"');
        receivablesAmt += (p2.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}

      // 8. Expense Category Breakdown in period
      try {
        final catWhere = filterPrefix != null ? "WHERE date LIKE '$filterPrefix%'" : "";
        final genCats = await db.rawQuery('SELECT categoryId, SUM(amount) as total FROM expenses $catWhere GROUP BY categoryId');
        for (var r in genCats) {
          final cat = r['categoryId'] as String? ?? 'General';
          final amt = (r['total'] as num?)?.toDouble() ?? 0.0;
          catBreakdown[cat] = (catBreakdown[cat] ?? 0.0) + amt;
        }
        try {
          final tripCats = await db.rawQuery('SELECT category, SUM(amount) as total FROM trip_expenses $catWhere GROUP BY category');
          for (var r in tripCats) {
            final cat = 'Trip: ${r['category'] as String? ?? 'Misc'}';
            final amt = (r['total'] as num?)?.toDouble() ?? 0.0;
            catBreakdown[cat] = (catBreakdown[cat] ?? 0.0) + amt;
          }
        } catch (_) {}
      } catch (_) {}

      // 9. Tasks & My Day Progress
      try {
        final todoList = await db.query('todos');
        tasksTotal = todoList.length;
        tasksDone = todoList.where((t) => (t['isCompleted'] ?? 0) == 1).length;

        final myDayWhere = filterPrefix != null ? "WHERE date LIKE '$filterPrefix%'" : "";
        final myDayList = await db.rawQuery("SELECT durationMinutes FROM my_day_tasks $myDayWhere");
        for (var m in myDayList) {
          schedMins += (m['durationMinutes'] as int? ?? 30);
        }
      } catch (_) {}

      // 10. Fetch Recent Transactions in period
      try {
        final recentExpWhere = filterPrefix != null ? "WHERE date LIKE '$filterPrefix%'" : "";
        final recentExpMaps = await db.rawQuery('SELECT * FROM expenses $recentExpWhere ORDER BY date DESC, createdAt DESC LIMIT 15');
        for (var m in recentExpMaps) {
          final exp = Expense.fromMap(m);
          activity.add(RecentActivityItem(
            id: exp.id,
            title: exp.location ?? exp.categoryId,
            subtitle: '${exp.date} • ${exp.paymentMethod}',
            amount: -exp.amount,
            date: exp.date,
            type: 'expense',
          ));
        }

        final recentIncWhere = filterPrefix != null ? "WHERE date LIKE '$filterPrefix%'" : "";
        final recentIncMaps = await db.rawQuery('SELECT * FROM income $recentIncWhere ORDER BY date DESC, createdAt DESC LIMIT 10');
        for (var m in recentIncMaps) {
          final inc = Income.fromMap(m);
          activity.add(RecentActivityItem(
            id: inc.id,
            title: inc.source,
            subtitle: '${inc.date} • ${inc.paymentMethod}',
            amount: inc.amount,
            date: inc.date,
            type: 'income',
          ));
        }

        try {
          final recentTripWhere = filterPrefix != null ? "WHERE date LIKE '$filterPrefix%'" : "";
          final recentTripMaps = await db.rawQuery('SELECT * FROM trip_expenses $recentTripWhere ORDER BY date DESC, createdAt DESC LIMIT 10');
          for (var m in recentTripMaps) {
            final title = m['title'] as String? ?? 'Trip Expense';
            final date = m['date'] as String? ?? '';
            final method = m['paymentMethod'] as String? ?? 'UPI';
            final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;
            final id = m['id'] as String? ?? '';
            activity.add(RecentActivityItem(
              id: id,
              title: title,
              subtitle: '$date • $method (Trip)',
              amount: -amt,
              date: date,
              type: 'trip_expense',
            ));
          }
        } catch (_) {}
      } catch (_) {}

      activity.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      debugPrint('Error in _loadDashboardData: $e');
    } finally {
      if (mounted) {
        setState(() {
          _totalIncome = totalInc;
          _totalExpenses = genExp + tripExp;
          _unpaidBills = unpaidBills;
          _savedMoney = savingsAmt;
          _customerReceivables = receivablesAmt;
          _todayTasksTotal = tasksTotal;
          _todayTasksCompleted = tasksDone;
          _scheduledMinutesToday = schedMins;
          _categoryBreakdown = catBreakdown;
          _recentActivity = activity.take(20).toList();
          _upiIncome = upiInc;
          _upiExpenses = upiExp;
          _cashIncome = cashInc;
          _cashExpenses = cashExp;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRecentActivity(RecentActivityItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction?'),
        content: Text('Are you sure you want to delete "${item.title}" (${item.amount > 0 ? '+' : ''}₹${item.amount.abs().toStringAsFixed(0)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negativeColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = await AppDatabase.instance.database;
      if (item.type == 'expense') {
        await db.delete('expenses', where: 'id = ?', whereArgs: [item.id]);
      } else if (item.type == 'income') {
        await db.delete('income', where: 'id = ?', whereArgs: [item.id]);
      } else if (item.type == 'trip_expense') {
        await db.delete('trip_expenses', where: 'id = ?', whereArgs: [item.id]);
      } else if (item.type == 'loan') {
        await db.delete('borrowed_money', where: 'id = ?', whereArgs: [item.id]);
      }

      try {
        if (mounted) {
          Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
        }
      } catch (_) {}
      AppNotificationScheduler.instance.scheduleDailyFinancialSummary();
      _loadDashboardData();
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final totalNetFunds = _totalIncome - _totalExpenses;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final availableTimeMins = (24 * 60) - _scheduledMinutesToday;
    final taskProgressPct = _todayTasksTotal > 0 ? (_todayTasksCompleted / _todayTasksTotal) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00F2FE), Color(0xFF0284C7)],
                ),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'LifeSync',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
            ),
            const SizedBox(width: 8),
            ListenableBuilder(
              listenable: AppTimeService.instance,
              builder: (context, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF00F2FE)),
                      const SizedBox(width: 4),
                      Text(
                        AppTimeService.instance.formattedTime,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 21),
            tooltip: 'AI Voice Assistant',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined, color: AppTheme.primaryLight),
            tooltip: 'Sync with Google Sheets Cloud',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Syncing data to Google Sheets... ☁️'),
                  duration: Duration(seconds: 2),
                ),
              );
              final res = await GoogleSheetsBackupService.instance.backupNow();
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Sync finished'),
                    backgroundColor: res['success'] == true ? AppTheme.positiveColor : AppTheme.negativeColor,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, size: 20),
            tooltip: 'Scan Payment Screenshot',
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentScannerScreen()),
              );
              if (res == true) _loadDashboardData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: 'Global Search',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined, size: 20),
            tooltip: 'Analytics',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Greeting & Contextual Summary
              Text(
                _getGreeting(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // Filter Bar (Date, Month [Default], Year, All)
              _buildFilterBar(isDark),

              const SizedBox(height: 14),

              // 2. Today Snapshot Strip
              _buildTodaySnapshot(isDark, availableTimeMins),

              const SizedBox(height: 16),

              // 3. Financial Snapshot (Available Funds Command Center Hero)
              _buildFinancialSnapshot(totalNetFunds, isDark),

              const SizedBox(height: 14),

              // 4. Wallet Balances (UPI & Cash)
              _buildWalletBalanceRow(isDark),

              const SizedBox(height: 16),

              // 5. Today's Progress Section
              const LifeSyncSectionHeader(title: "Today's Progress"),
              LifeSyncProgressCard(
                title: 'Daily Tasks Progress',
                subtitle: '$_todayTasksCompleted of $_todayTasksTotal tasks completed',
                progress: taskProgressPct,
                progressLabel: '${(taskProgressPct * 100).toStringAsFixed(0)}%',
                progressColor: AppTheme.positiveColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TodosScreen())),
              ),
              const SizedBox(height: 6),
              const HomeHealthSummaryCard(),

              const SizedBox(height: 18),

              // 6. Quick Actions Grid
              const LifeSyncSectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 6),
              _buildQuickActionsGrid(context, isDark),

              const SizedBox(height: 20),

              // 7. Financial Flow Analytics Panel
              _buildInteractiveGraphCard(isDark),

              const SizedBox(height: 20),

              // 8. Recent Activity Stream
              LifeSyncSectionHeader(
                title: 'Activity (${_getPeriodBadgeLabel()})',
                actionLabel: 'View All →',
                onAction: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()));
                  _loadDashboardData();
                },
              ),
              const SizedBox(height: 6),

              _isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                  : _recentActivity.isEmpty
                      ? LifeSyncEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No activity in this period',
                          message: 'No transactions found for ${_getFormattedPeriodLabel()}.',
                        )
                      : Builder(
                          builder: (context) {
                            final totalPages = (_recentActivity.length / _activityPageSize).ceil();
                            final safePage = totalPages == 0 ? 1 : _activityPage.clamp(1, totalPages);
                            final pagedItems = _recentActivity.skip((safePage - 1) * _activityPageSize).take(_activityPageSize).toList();

                            return Column(
                              children: [
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: pagedItems.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final item = pagedItems[index];
                                    final isIncome = item.amount > 0;
                                    final isTrip = item.type == 'trip_expense';

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                          width: 1,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: isIncome
                                                  ? AppTheme.positiveColor.withAlpha(35)
                                                  : (isTrip ? AppTheme.infoColor.withAlpha(35) : AppTheme.negativeColor.withAlpha(35)),
                                              child: Icon(
                                                isIncome
                                                    ? Icons.arrow_downward_rounded
                                                    : (isTrip ? Icons.flight_takeoff_rounded : Icons.arrow_upward_rounded),
                                                color: isIncome
                                                    ? AppTheme.positiveColor
                                                    : (isTrip ? AppTheme.infoColor : AppTheme.negativeColor),
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    item.title,
                                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    item.subtitle,
                                                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              AppTheme.formatCurrency(item.amount, showSign: true, isIncome: isIncome),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isIncome ? AppTheme.positiveColor : AppTheme.negativeColor,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              onPressed: () => _deleteRecentActivity(item),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (totalPages > 1) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Showing ${(safePage - 1) * _activityPageSize + 1}-${((safePage - 1) * _activityPageSize + pagedItems.length)} of ${_recentActivity.length}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.chevron_left, size: 20),
                                            visualDensity: VisualDensity.compact,
                                            onPressed: safePage > 1 ? () => setState(() => _activityPage--) : null,
                                          ),
                                          Text('$safePage / $totalPages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          IconButton(
                                            icon: const Icon(Icons.chevron_right, size: 20),
                                            visualDensity: VisualDensity.compact,
                                            onPressed: safePage < totalPages ? () => setState(() => _activityPage++) : null,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ================= Filter Bar & Period Navigator =================

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Filter Type Pill Switcher
          Row(
            children: [
              _buildFilterTypeChip(DashboardDateFilterType.day, 'Date', Icons.calendar_today_rounded, isDark),
              const SizedBox(width: 6),
              _buildFilterTypeChip(DashboardDateFilterType.month, 'Month', Icons.calendar_month_rounded, isDark),
              const SizedBox(width: 6),
              _buildFilterTypeChip(DashboardDateFilterType.year, 'Year', Icons.event_note_rounded, isDark),
              const SizedBox(width: 6),
              _buildFilterTypeChip(DashboardDateFilterType.all, 'All Time', Icons.all_inclusive_rounded, isDark),
            ],
          ),
          if (_filterType != DashboardDateFilterType.all) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Period Navigator Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Arrow
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 24),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () => _navigatePeriod(-1),
                  tooltip: 'Previous ${_getPeriodTypeUnit()}',
                ),
                // Center Clickable Period Button
                Expanded(
                  child: InkWell(
                    onTap: _showPeriodPicker,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _filterType == DashboardDateFilterType.day
                                ? Icons.today_rounded
                                : _filterType == DashboardDateFilterType.month
                                    ? Icons.date_range_rounded
                                    : Icons.calendar_view_month_rounded,
                            size: 15,
                            color: AppTheme.primaryLight,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _getFormattedPeriodLabel(),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down_rounded, size: 20, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
                // Right Arrow
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 24),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () => _navigatePeriod(1),
                  tooltip: 'Next ${_getPeriodTypeUnit()}',
                ),
                if (!_isCurrentPeriod()) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      setState(() => _selectedDate = DateTime.now());
                      _loadDashboardData();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryColor.withAlpha(80), width: 1),
                      ),
                      child: Text(
                        _getResetButtonLabel(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterTypeChip(DashboardDateFilterType type, String label, IconData icon, bool isDark) {
    final isSelected = _filterType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_filterType != type) {
            setState(() {
              _filterType = type;
            });
            _loadDashboardData();
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? AppTheme.darkBorder.withAlpha(50) : AppTheme.lightBorder.withAlpha(100)),
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 12,
                color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPeriodTypeUnit() {
    switch (_filterType) {
      case DashboardDateFilterType.day:
        return 'Day';
      case DashboardDateFilterType.month:
        return 'Month';
      case DashboardDateFilterType.year:
        return 'Year';
      case DashboardDateFilterType.all:
        return '';
    }
  }

  String _getFormattedPeriodLabel() {
    switch (_filterType) {
      case DashboardDateFilterType.day:
        final now = DateTime.now();
        if (_selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day) {
          return 'Today (${DateFormat('d MMM yyyy').format(_selectedDate)})';
        }
        return DateFormat('EEE, d MMM yyyy').format(_selectedDate);
      case DashboardDateFilterType.month:
        return DateFormat('MMMM yyyy').format(_selectedDate);
      case DashboardDateFilterType.year:
        return 'Year ${DateFormat('yyyy').format(_selectedDate)}';
      case DashboardDateFilterType.all:
        return 'All Time History';
    }
  }

  String _getPeriodBadgeLabel() {
    switch (_filterType) {
      case DashboardDateFilterType.day:
        return DateFormat('d MMM').format(_selectedDate);
      case DashboardDateFilterType.month:
        return DateFormat('MMM yyyy').format(_selectedDate);
      case DashboardDateFilterType.year:
        return DateFormat('yyyy').format(_selectedDate);
      case DashboardDateFilterType.all:
        return 'All Time';
    }
  }

  bool _isCurrentPeriod() {
    final now = DateTime.now();
    switch (_filterType) {
      case DashboardDateFilterType.day:
        return _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
      case DashboardDateFilterType.month:
        return _selectedDate.year == now.year && _selectedDate.month == now.month;
      case DashboardDateFilterType.year:
        return _selectedDate.year == now.year;
      case DashboardDateFilterType.all:
        return true;
    }
  }

  String _getResetButtonLabel() {
    switch (_filterType) {
      case DashboardDateFilterType.day:
        return 'Today';
      case DashboardDateFilterType.month:
        return 'This Month';
      case DashboardDateFilterType.year:
        return 'This Year';
      case DashboardDateFilterType.all:
        return '';
    }
  }

  void _navigatePeriod(int delta) {
    setState(() {
      switch (_filterType) {
        case DashboardDateFilterType.day:
          _selectedDate = _selectedDate.add(Duration(days: delta));
          break;
        case DashboardDateFilterType.month:
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta, 1);
          break;
        case DashboardDateFilterType.year:
          _selectedDate = DateTime(_selectedDate.year + delta, 1, 1);
          break;
        case DashboardDateFilterType.all:
          break;
      }
    });
    _loadDashboardData();
  }

  Future<void> _showPeriodPicker() async {
    if (_filterType == DashboardDateFilterType.day) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );
      if (picked != null) {
        setState(() => _selectedDate = picked);
        _loadDashboardData();
      }
    } else if (_filterType == DashboardDateFilterType.month) {
      await _showMonthPickerSheet();
    } else if (_filterType == DashboardDateFilterType.year) {
      await _showYearPickerDialog();
    }
  }

  Future<void> _showMonthPickerSheet() async {
    int pickerYear = _selectedDate.year;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            final now = DateTime.now();
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Select Month 📅', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Year Selector Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () => setSheetState(() => pickerYear--),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$pickerYear',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () => setSheetState(() => pickerYear++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Month Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.8,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected = _selectedDate.year == pickerYear && _selectedDate.month == monthNum;
                      final isCurrent = now.year == pickerYear && now.month == monthNum;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDate = DateTime(pickerYear, monthNum, 1);
                          });
                          Navigator.pop(ctx);
                          _loadDashboardData();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : (isCurrent ? AppTheme.primaryColor.withAlpha(30) : null),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : (isCurrent ? AppTheme.primaryColor : Colors.grey.withAlpha(60)),
                              width: isCurrent ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            months[index],
                            style: TextStyle(
                              fontWeight: isSelected || isCurrent ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showYearPickerDialog() async {
    final currentYear = DateTime.now().year;
    final years = List.generate(16, (i) => 2020 + i);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Year 🗓️', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.8,
                ),
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final yr = years[index];
                  final isSelected = _selectedDate.year == yr;
                  final isCurrent = currentYear == yr;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDate = DateTime(yr, 1, 1);
                      });
                      Navigator.pop(ctx);
                      _loadDashboardData();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : (isCurrent ? AppTheme.primaryColor.withAlpha(30) : null),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : (isCurrent ? AppTheme.primaryColor : Colors.grey.withAlpha(60)),
                          width: isCurrent ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        '$yr',
                        style: TextStyle(
                          fontWeight: isSelected || isCurrent ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ================= 2. Today / Period Snapshot =================

  Widget _buildTodaySnapshot(bool isDark, int availableTimeMins) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          LifeSyncMetricPill(
            icon: Icons.hourglass_top_rounded,
            label: _filterType == DashboardDateFilterType.day ? 'Free Time' : 'Scheduled',
            value: _filterType == DashboardDateFilterType.day
                ? AppTheme.formatMinutes(availableTimeMins.clamp(0, 1440))
                : AppTheme.formatMinutes(_scheduledMinutesToday),
            color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
          ),
          Container(width: 1, height: 28, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          const SizedBox(width: 10),
          LifeSyncMetricPill(
            icon: Icons.task_alt_rounded,
            label: 'Tasks',
            value: '$_todayTasksCompleted/$_todayTasksTotal',
            color: AppTheme.positiveColor,
          ),
          Container(width: 1, height: 28, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          const SizedBox(width: 10),
          LifeSyncMetricPill(
            icon: Icons.arrow_downward_rounded,
            label: _filterType == DashboardDateFilterType.day
                ? 'Day Income'
                : _filterType == DashboardDateFilterType.month
                    ? 'Month Income'
                    : _filterType == DashboardDateFilterType.year
                        ? 'Year Income'
                        : 'Total Income',
            value: AppTheme.formatCurrency(_totalIncome),
            color: AppTheme.positiveColor,
          ),
          Container(width: 1, height: 28, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          const SizedBox(width: 10),
          LifeSyncMetricPill(
            icon: Icons.arrow_upward_rounded,
            label: _filterType == DashboardDateFilterType.day
                ? 'Day Spent'
                : _filterType == DashboardDateFilterType.month
                    ? 'Month Spent'
                    : _filterType == DashboardDateFilterType.year
                        ? 'Year Spent'
                        : 'Total Spent',
            value: AppTheme.formatCurrency(_totalExpenses),
            color: AppTheme.negativeColor,
          ),
        ],
      ),
    );
  }

  // ================= 3. Financial Snapshot =================

  Widget _buildFinancialSnapshot(double totalNetFunds, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    _filterType == DashboardDateFilterType.day
                        ? 'Daily Cashflow 💰'
                        : _filterType == DashboardDateFilterType.month
                            ? 'Monthly Cashflow 💰'
                            : _filterType == DashboardDateFilterType.year
                                ? 'Annual Cashflow 💰'
                                : 'Available Liquid Funds 💰',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getPeriodBadgeLabel(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen())),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'View Finance →',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppTheme.formatCurrency(totalNetFunds),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              LifeSyncMetricPill(
                label: 'Income Streams',
                value: AppTheme.formatCurrency(_totalIncome, showSign: true, isIncome: true),
                color: AppTheme.positiveColor,
              ),
              LifeSyncMetricPill(
                label: 'Total Expenses',
                value: AppTheme.formatCurrency(-_totalExpenses, showSign: true),
                color: AppTheme.negativeColor,
              ),
              LifeSyncMetricPill(
                label: 'Unpaid Bills',
                value: AppTheme.formatCurrency(_unpaidBills),
                color: AppTheme.warningColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= 4. Wallet Balance Row =================

  Widget _buildWalletBalanceRow(bool isDark) {
    Widget walletCard(String label, IconData icon, double balance, double inc, double exp, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withAlpha(50),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withAlpha(35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 14, color: color),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                AppTheme.formatCurrency(balance),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: balance < 0 ? AppTheme.negativeColor : color,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('+${AppTheme.formatCurrency(inc)}', style: const TextStyle(fontSize: 10, color: AppTheme.positiveColor, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text('-${AppTheme.formatCurrency(exp)}', style: const TextStyle(fontSize: 10, color: AppTheme.negativeColor, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        walletCard('UPI Wallet', Icons.account_balance_outlined, _upiBalance, _upiIncome, _upiExpenses, const Color(0xFF6366F1)),
        const SizedBox(width: 10),
        walletCard('Cash in Hand', Icons.payments_outlined, _cashBalance, _cashIncome, _cashExpenses, AppTheme.positiveColor),
      ],
    );
  }

  // ================= 6. Quick Actions Grid =================

  Widget _buildQuickActionsGrid(BuildContext context, bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 10,
      children: [
        _buildShortcutItem(context, 'Scan', Icons.center_focus_strong, AppTheme.primaryColor, () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScannerScreen()));
          if (res == true) _loadDashboardData();
        }),
        _buildShortcutItem(context, 'Add Expense', Icons.remove_circle_outline, AppTheme.negativeColor, () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()));
          _loadDashboardData();
        }),
        _buildShortcutItem(context, 'Add Income', Icons.add_circle_outline, AppTheme.positiveColor, () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const IncomeScreen()));
          _loadDashboardData();
        }),
        _buildShortcutItem(context, 'Tasks', Icons.task_alt_rounded, const Color(0xFF6366F1), () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const TodosScreen()));
          _loadDashboardData();
        }),
        _buildShortcutItem(context, 'My Day', Icons.calendar_today_rounded, const Color(0xFF06B6D4), () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyDayScreen()));
          _loadDashboardData();
        }),
        _buildShortcutItem(context, 'Budget', Icons.pie_chart_outline, Colors.orange, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetScreen()));
        }),
        _buildShortcutItem(context, 'Savings', Icons.savings_outlined, const Color(0xFF8B5CF6), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingsScreen()));
        }),
        _buildShortcutItem(context, 'Net Worth', Icons.show_chart_rounded, const Color(0xFF9333EA), () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const NetWorthScreen()));
          _loadDashboardData();
        }),
        _buildShortcutItem(context, 'Trips', Icons.flight_takeoff_rounded, const Color(0xFF0284C7), () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const NavigationScreen()));
          _loadDashboardData();
        }),
        _buildShortcutItem(context, 'Bills', Icons.receipt_outlined, Colors.amber.shade800, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const BillsScreen()));
        }),
        _buildShortcutItem(context, 'Customers', Icons.people_outline, Colors.indigo, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen()));
        }),
        _buildShortcutItem(context, 'Settings', Icons.settings_outlined, Colors.blueGrey, () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          _loadDashboardData();
        }),
      ],
    );
  }

  Widget _buildShortcutItem(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ================= 7. Financial Flow Graphs =================

  Widget _buildInteractiveGraphCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Financial Flow (${_getPeriodBadgeLabel()})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Flow', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 1, label: Text('Breakdown', style: TextStyle(fontSize: 11))),
                ],
                selected: {_activeChartIndex},
                onSelectionChanged: (val) {
                  setState(() => _activeChartIndex = val.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _activeChartIndex == 0
              ? _buildCashflowBarChart(isDark)
              : _buildExpenseCategoryDonutChart(isDark),
        ],
      ),
    );
  }

  Widget _buildCashflowBarChart(bool isDark) {
    final maxVal = [
      _totalIncome,
      _totalExpenses,
      _savedMoney,
      _unpaidBills,
      _customerReceivables,
    ].reduce((a, b) => a > b ? a : b);

    final maxY = maxVal > 0 ? maxVal * 1.25 : 1000.0;

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final labels = ['Income', 'Spent', 'Savings', 'Unpaid Bills', 'Receivables'];
                    return BarTooltipItem(
                      '${labels[group.x.toInt()]}\n₹${rod.toY.toStringAsFixed(0)}',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const titles = ['Income', 'Spent', 'Saved', 'Bills', 'Receiv.'];
                      final idx = value.toInt();
                      if (idx >= 0 && idx < titles.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            titles[idx],
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: [
                BarChartGroupData(x: 0, barRods: [
                  BarChartRodData(toY: _totalIncome, color: AppTheme.positiveColor, width: 14, borderRadius: BorderRadius.circular(4)),
                ]),
                BarChartGroupData(x: 1, barRods: [
                  BarChartRodData(toY: _totalExpenses, color: AppTheme.negativeColor, width: 14, borderRadius: BorderRadius.circular(4)),
                ]),
                BarChartGroupData(x: 2, barRods: [
                  BarChartRodData(toY: _savedMoney, color: const Color(0xFF8B5CF6), width: 14, borderRadius: BorderRadius.circular(4)),
                ]),
                BarChartGroupData(x: 3, barRods: [
                  BarChartRodData(toY: _unpaidBills, color: AppTheme.warningColor, width: 14, borderRadius: BorderRadius.circular(4)),
                ]),
                BarChartGroupData(x: 4, barRods: [
                  BarChartRodData(toY: _customerReceivables, color: Colors.teal, width: 14, borderRadius: BorderRadius.circular(4)),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildChartLegendItem('Income', AppTheme.positiveColor),
            const SizedBox(width: 12),
            _buildChartLegendItem('Spent', AppTheme.negativeColor),
            const SizedBox(width: 12),
            _buildChartLegendItem('Saved', const Color(0xFF8B5CF6)),
            const SizedBox(width: 12),
            _buildChartLegendItem('Bills', AppTheme.warningColor),
          ],
        ),
      ],
    );
  }

  Widget _buildExpenseCategoryDonutChart(bool isDark) {
    if (_categoryBreakdown.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('No expenditure logged yet for breakdown chart.')),
      );
    }

    final chartColors = [
      AppTheme.primaryColor,
      const Color(0xFF8B5CF6),
      AppTheme.positiveColor,
      AppTheme.warningColor,
      AppTheme.negativeColor,
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];

    final entries = _categoryBreakdown.entries.toList();

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 36,
              sections: entries.map((e) {
                final idx = entries.indexOf(e);
                final color = chartColors[idx % chartColors.length];
                final pct = _totalExpenses > 0 ? (e.value / _totalExpenses * 100) : 0;
                return PieChartSectionData(
                  color: color,
                  value: e.value,
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: 36,
                  titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: entries.take(6).map((e) {
            final idx = entries.indexOf(e);
            final color = chartColors[idx % chartColors.length];
            return _buildChartLegendItem('${e.key}: ₹${e.value.toStringAsFixed(0)}', color);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChartLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
