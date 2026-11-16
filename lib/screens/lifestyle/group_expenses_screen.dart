import 'package:flutter/material.dart';

class GroupExpensesScreen extends StatefulWidget {
  const GroupExpensesScreen({super.key});

  @override
  State<GroupExpensesScreen> createState() => _GroupExpensesScreenState();
}

class _GroupExpensesScreenState extends State<GroupExpensesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group Expense Splitter')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.group_rounded, size: 64, color: Colors.indigo),
              SizedBox(height: 16),
              Text(
                'Split Bills & Shared Expenses',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Equal splits, custom proportions, and balance settlements.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
