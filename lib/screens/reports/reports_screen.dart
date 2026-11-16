import 'package:flutter/material.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../services/export_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isExporting = false;

  Future<void> _exportExpensesPdf() async {
    setState(() => _isExporting = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('expenses', orderBy: 'date DESC');
    final expenses = maps.map((e) => Expense.fromMap(e)).toList();

    final headers = ['Date', 'Category', 'Payment Method', 'Amount (INR)', 'Notes'];
    final data = expenses
        .map((e) => [
              e.date,
              e.categoryId,
              e.paymentMethod,
              'Rs. ${e.amount.toStringAsFixed(2)}',
              e.notes ?? ''
            ])
        .toList();

    final pdfFile = await ExportService.generatePdfReport(
      title: 'Expense_Report',
      headers: headers,
      tableData: data,
    );

    setState(() => _isExporting = false);
    await ExportService.shareFile(pdfFile.path, text: 'LifeSync Expense PDF Report');
  }

  Future<void> _exportTripExpensesPdf() async {
    setState(() => _isExporting = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('trip_expenses', orderBy: 'date DESC');
    final tripExpList = maps.map((e) => TripExpense.fromMap(e)).toList();

    final headers = ['Date', 'Trip Expense', 'Category', 'Payment', 'Amount (INR)'];
    final data = tripExpList
        .map((e) => [
              e.date,
              e.title,
              e.category,
              e.paymentMethod,
              'Rs. ${e.amount.toStringAsFixed(2)}',
            ])
        .toList();

    final pdfFile = await ExportService.generatePdfReport(
      title: 'Trip_Vacation_Expense_Report',
      headers: headers,
      tableData: data,
    );

    setState(() => _isExporting = false);
    await ExportService.shareFile(pdfFile.path, text: 'LifeSync Trip Expenses PDF Report');
  }

  Future<void> _exportExpensesCsv() async {
    setState(() => _isExporting = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('expenses', orderBy: 'date DESC');
    final expenses = maps.map((e) => Expense.fromMap(e)).toList();

    final headers = ['Date', 'Category', 'Payment Method', 'Amount', 'Notes'];
    final data = expenses
        .map((e) => [
              e.date,
              e.categoryId,
              e.paymentMethod,
              e.amount.toStringAsFixed(2),
              e.notes ?? ''
            ])
        .toList();

    final csvFile = await ExportService.generateCsvReport(
      title: 'Expense_Report',
      headers: headers,
      tableData: data,
    );

    setState(() => _isExporting = false);
    await ExportService.shareFile(csvFile.path, text: 'LifeSync Expense CSV Data');
  }

  Future<void> _exportIncomePdf() async {
    setState(() => _isExporting = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('income', orderBy: 'date DESC');
    final incomeList = maps.map((e) => Income.fromMap(e)).toList();

    final headers = ['Date', 'Source', 'Payment Method', 'Amount (INR)', 'Taxable'];
    final data = incomeList
        .map((e) => [
              e.date,
              e.source,
              e.paymentMethod,
              'Rs. ${e.amount.toStringAsFixed(2)}',
              e.isTaxRelevant ? 'Yes' : 'No'
            ])
        .toList();

    final pdfFile = await ExportService.generatePdfReport(
      title: 'Income_Report',
      headers: headers,
      tableData: data,
    );

    setState(() => _isExporting = false);
    await ExportService.shareFile(pdfFile.path, text: 'LifeSync Income PDF Report');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Vault & Export')),
      body: _isExporting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Generate Printable & Exportable Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 36),
                    title: const Text('Expense PDF Report', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Export all general expense records into formatted PDF table'),
                    trailing: ElevatedButton(
                      onPressed: _exportExpensesPdf,
                      child: const Text('Export PDF'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.flight_takeoff_rounded, color: Color(0xFF0284C7), size: 36),
                    title: const Text('Trip & Travel Expense Report', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Export vacation and trip expense records into PDF table'),
                    trailing: ElevatedButton(
                      onPressed: _exportTripExpensesPdf,
                      child: const Text('Export PDF'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.table_chart_rounded, color: Colors.green, size: 36),
                    title: const Text('Expense CSV Spreadsheet', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Export expense records to CSV format for Excel'),
                    trailing: ElevatedButton(
                      onPressed: _exportExpensesCsv,
                      child: const Text('Export CSV'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.indigo, size: 36),
                    title: const Text('Income Statement PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Export income channels and tax classification summary'),
                    trailing: ElevatedButton(
                      onPressed: _exportIncomePdf,
                      child: const Text('Export PDF'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
