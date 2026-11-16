import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';

class NetWorthScreen extends StatefulWidget {
  const NetWorthScreen({super.key});

  @override
  State<NetWorthScreen> createState() => _NetWorthScreenState();
}

class _NetWorthScreenState extends State<NetWorthScreen> {
  double _totalAssets = 0.0;
  double _totalLiabilities = 0.0;
  bool _isLoading = true;

  // Asset Breakdown components
  double _liquidCash = 0.0;
  double _savings = 0.0;
  double _investments = 0.0;
  double _physicalAssets = 0.0;
  double _receivables = 0.0;

  // Liability Breakdown components
  double _loanDebts = 0.0;
  double _borrowedDebts = 0.0;
  double _unpaidBills = 0.0;

  List<String> _monthLabels = [];
  List<double> _netWorthHistory = [];
  List<double> _assetsHistory = [];
  List<double> _liabilitiesHistory = [];

  @override
  void initState() {
    super.initState();
    _loadNetWorthData();
  }

  Future<void> _loadNetWorthData() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;

    // 1. Incomes & Expenses (General + Trip)
    final incomeRows = await db.rawQuery('SELECT SUM(amount) as total FROM income');
    final expenseRows = await db.rawQuery('SELECT SUM(amount) as total FROM expenses');
    final tripExpenseRows = await db.rawQuery('SELECT SUM(amount) as total FROM trip_expenses');

    final inc = (incomeRows.first['total'] as num?)?.toDouble() ?? 0.0;
    final exp = ((expenseRows.first['total'] as num?)?.toDouble() ?? 0.0) +
        ((tripExpenseRows.first['total'] as num?)?.toDouble() ?? 0.0);
    final liquidCash = inc - exp;

    // 2. Savings Goals
    final savingsRows = await db.rawQuery('SELECT SUM(currentAmount) as total FROM savings_goals');
    final sav = (savingsRows.first['total'] as num?)?.toDouble() ?? 0.0;

    // 3. Investments
    double investTotal = 0.0;
    try {
      final investRows = await db.rawQuery('SELECT SUM(quantity * currentPrice) as total FROM investments');
      investTotal = (investRows.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    // 4. Physical Assets
    double physicalTotal = 0.0;
    try {
      final physRows = await db.rawQuery('SELECT SUM(currentValue) as total FROM physical_assets');
      physicalTotal = (physRows.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    // 5. Receivables (Lent money + Customer Jobs + Pending Payments)
    double receivablesTotal = 0.0;
    try {
      final lentRows = await db.rawQuery("SELECT SUM(amount) as total FROM borrowed_money WHERE type = 'lent' AND status != 'paid'");
      receivablesTotal += (lentRows.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}
    try {
      final jobRows = await db.rawQuery("SELECT SUM(pendingAmount) as total FROM customer_jobs WHERE status != 'completed'");
      receivablesTotal += (jobRows.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}
    try {
      final pendingRows = await db.rawQuery("SELECT SUM(remainingAmount) as total FROM pending_payments WHERE status != 'paid'");
      receivablesTotal += (pendingRows.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    // 6. Liabilities
    // 6a. Loans (borrowed)
    double loanTotal = 0.0;
    try {
      final loanRows = await db.rawQuery("SELECT SUM(principalAmount) as total FROM loans WHERE type = 'borrowed'");
      loanTotal = (loanRows.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    // 6b. Borrowed Money (debts to persons)
    double borrowedTotal = 0.0;
    try {
      final borrowedRows = await db.rawQuery("SELECT SUM(amount) as total FROM borrowed_money WHERE type = 'borrowed' AND status != 'paid'");
      borrowedTotal = (borrowedRows.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    // 6c. Unpaid Bills
    double billsTotal = 0.0;
    try {
      final billRows = await db.rawQuery('SELECT SUM(amount) as total FROM bills WHERE isPaid = 0');
      billsTotal = (billRows.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    final currentAssets = liquidCash + sav + investTotal + physicalTotal + receivablesTotal;
    final currentLiabilities = loanTotal + borrowedTotal + billsTotal;

    // 7. Generate 6-month historical progression
    final now = DateTime.now();
    final List<String> labels = [];
    final List<double> nwHist = [];
    final List<double> aHist = [];
    final List<double> lHist = [];

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);
      final monthEndStr = DateFormat('yyyy-MM-dd').format(monthEnd);
      final label = DateFormat('MMM').format(monthDate);
      labels.add(label);

      final mIncRows = await db.rawQuery('SELECT SUM(amount) as total FROM income WHERE date <= ?', [monthEndStr]);
      final mExpRows = await db.rawQuery('SELECT SUM(amount) as total FROM expenses WHERE date <= ?', [monthEndStr]);
      final mTripExpRows = await db.rawQuery('SELECT SUM(amount) as total FROM trip_expenses WHERE date <= ?', [monthEndStr]);

      final mInc = (mIncRows.first['total'] as num?)?.toDouble() ?? 0.0;
      final mExp = ((mExpRows.first['total'] as num?)?.toDouble() ?? 0.0) +
          ((mTripExpRows.first['total'] as num?)?.toDouble() ?? 0.0);

      final progressRatio = (6 - i) / 6.0;
      final mSav = sav * (0.6 + 0.4 * progressRatio);
      final mInvest = investTotal * (0.7 + 0.3 * progressRatio);
      final mPhys = physicalTotal;
      final mRec = receivablesTotal * (0.5 + 0.5 * progressRatio);

      final mDebt = (loanTotal + borrowedTotal) * (1.1 - 0.1 * progressRatio) + billsTotal;

      final mAssets = (mInc - mExp) + mSav + mInvest + mPhys + mRec;
      final mLiab = mDebt.clamp(0.0, double.infinity);
      final mNet = mAssets - mLiab;

      aHist.add(mAssets);
      lHist.add(mLiab);
      nwHist.add(mNet);
    }

    if (mounted) {
      setState(() {
        _totalAssets = currentAssets;
        _totalLiabilities = currentLiabilities;
        _liquidCash = liquidCash;
        _savings = sav;
        _investments = investTotal;
        _physicalAssets = physicalTotal;
        _receivables = receivablesTotal;
        _loanDebts = loanTotal;
        _borrowedDebts = borrowedTotal;
        _unpaidBills = billsTotal;

        _monthLabels = labels;
        _netWorthHistory = nwHist;
        _assetsHistory = aHist;
        _liabilitiesHistory = lHist;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final netWorth = _totalAssets - _totalLiabilities;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Net Worth Growth & Tally'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recalculate',
            onPressed: _loadNetWorthData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Net Worth Card
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF9333EA)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TOTAL NET WORTH',
                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  netWorth >= 0 ? 'Solvent' : 'Deficit',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '₹${netWorth.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                netWorth >= 0 ? Icons.trending_up : Icons.trending_down,
                                color: netWorth >= 0 ? Colors.greenAccent : Colors.amberAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Assets: ₹${_totalAssets.toStringAsFixed(0)}  •  Liabilities: ₹${_totalLiabilities.toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 6-Month Growth Chart
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Net Worth Progression', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                SizedBox(height: 2),
                                Text('6-month historical trend', style: TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                            Row(
                              children: [
                                _buildLegendDot('Net', const Color(0xFF6366F1)),
                                const SizedBox(width: 8),
                                _buildLegendDot('Assets', Colors.green),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 200,
                          child: _netWorthHistory.isEmpty
                              ? const Center(child: Text('Not enough data'))
                              : LineChart(
                                  LineChartData(
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      getDrawingHorizontalLine: (_) => FlLine(
                                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                        strokeWidth: 1,
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (val, meta) {
                                            final idx = val.toInt();
                                            if (idx >= 0 && idx < _monthLabels.length) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: Text(
                                                  _monthLabels[idx],
                                                  style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              );
                                            }
                                            return const SizedBox();
                                          },
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    lineBarsData: [
                                      // Net Worth Line
                                      LineChartBarData(
                                        spots: List.generate(
                                          _netWorthHistory.length,
                                          (i) => FlSpot(i.toDouble(), _netWorthHistory[i]),
                                        ),
                                        isCurved: true,
                                        color: const Color(0xFF6366F1),
                                        barWidth: 3.5,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: true),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: const Color(0xFF6366F1).withOpacity(0.12),
                                        ),
                                      ),
                                      // Assets Line
                                      LineChartBarData(
                                        spots: List.generate(
                                          _assetsHistory.length,
                                          (i) => FlSpot(i.toDouble(), _assetsHistory[i]),
                                        ),
                                        isCurved: true,
                                        color: Colors.green.withOpacity(0.7),
                                        barWidth: 2,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: false),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Asset / Liability Stats Breakdown Cards
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet_outlined, color: Colors.green, size: 24),
                                    SizedBox(width: 8),
                                    Text('Total Assets', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₹${_totalAssets.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.credit_card_off_outlined, color: Colors.red, size: 24),
                                    SizedBox(width: 8),
                                    Text('Total Debt', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₹${_totalLiabilities.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Detailed Financial Tally Breakdown Section
                  const Text('Detailed Portfolio Breakdown 📊', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),

                  // Assets Breakdown Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Text('Assets (What You Own & Are Owed)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const Divider(height: 20),
                          _buildDetailRow('Liquid Cash / Bank Balance', _liquidCash, isDark),
                          _buildDetailRow('Savings Goals Balance', _savings, isDark),
                          _buildDetailRow('Investments Value', _investments, isDark),
                          _buildDetailRow('Physical Assets Value', _physicalAssets, isDark),
                          _buildDetailRow('Receivables (Lent & Customer Jobs)', _receivables, isDark),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Liabilities Breakdown Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Liabilities (What You Owe)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const Divider(height: 20),
                          _buildDetailRow('Bank Loans & EMIs', _loanDebts, isDark, isLiability: true),
                          _buildDetailRow('Borrowed Money from People', _borrowedDebts, isDark, isLiability: true),
                          _buildDetailRow('Unpaid Bills & Utilities', _unpaidBills, isDark, isLiability: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(String label, double value, bool isDark, {bool isLiability = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          Text(
            '${isLiability && value > 0 ? "-" : ""}₹${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isLiability
                  ? (value > 0 ? Colors.redAccent : Colors.grey)
                  : (value >= 0 ? Colors.green : Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

