import 'package:flutter/material.dart';
import '../../database/app_database.dart';

class HealthScoreScreen extends StatefulWidget {
  const HealthScoreScreen({super.key});

  @override
  State<HealthScoreScreen> createState() => _HealthScoreScreenState();
}

class _HealthScoreScreenState extends State<HealthScoreScreen> {
  int _score = 75;
  double _savingsRate = 0.0;
  double _debtToIncome = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateScore();
  }

  Future<void> _calculateScore() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;

    final incomeRows = await db.rawQuery('SELECT SUM(amount) as total FROM income');
    final expenseRows = await db.rawQuery('SELECT SUM(amount) as total FROM expenses');
    final loanRows = await db.rawQuery('SELECT SUM(principalAmount) as total FROM loans WHERE type = "borrowed"');

    final inc = (incomeRows.first['total'] as num?)?.toDouble() ?? 0.0;
    final exp = (expenseRows.first['total'] as num?)?.toDouble() ?? 0.0;
    final debt = (loanRows.first['total'] as num?)?.toDouble() ?? 0.0;

    double sRate = 0.0;
    double dRatio = 0.0;

    if (inc > 0) {
      sRate = ((inc - exp) / inc) * 100;
      dRatio = (debt / (inc * 12)) * 100;
    }

    int calculatedScore = 50;
    if (sRate > 30) calculatedScore += 25;
    else if (sRate > 15) calculatedScore += 15;

    if (dRatio < 20) calculatedScore += 25;
    else if (dRatio < 35) calculatedScore += 15;

    setState(() {
      _score = calculatedScore.clamp(0, 100);
      _savingsRate = sRate;
      _debtToIncome = dRatio;
      _isLoading = false;
    });
  }

  Color _scoreColor(int s) {
    if (s >= 80) return Colors.green;
    if (s >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(_score);

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Health Score')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_score',
                          style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: color),
                        ),
                        const Text('Out of 100', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.savings_outlined, color: Colors.teal),
                      title: const Text('Savings Rate'),
                      trailing: Text('${_savingsRate.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.money_off_outlined, color: Colors.orange),
                      title: const Text('Debt-to-Income Ratio'),
                      trailing: Text('${_debtToIncome.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
