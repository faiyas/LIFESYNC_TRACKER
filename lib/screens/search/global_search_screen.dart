import 'package:flutter/material.dart';
import '../../database/app_database.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _results = [];
  bool _isSearching = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final db = await AppDatabase.instance.database;
    final List<Map<String, String>> searchResults = [];

    // Search Expenses
    final expRows = await db.rawQuery(
      'SELECT categoryId, amount, date FROM expenses WHERE categoryId LIKE ? OR notes LIKE ?',
      ['%$query%', '%$query%'],
    );
    for (var r in expRows) {
      searchResults.add({
        'module': 'Expense',
        'title': '${r['categoryId']} (₹${r['amount']})',
        'subtitle': 'Date: ${r['date']}',
      });
    }

    // Search Income
    final incRows = await db.rawQuery(
      'SELECT source, amount, date FROM income WHERE source LIKE ? OR notes LIKE ?',
      ['%$query%', '%$query%'],
    );
    for (var r in incRows) {
      searchResults.add({
        'module': 'Income',
        'title': '${r['source']} (+₹${r['amount']})',
        'subtitle': 'Date: ${r['date']}',
      });
    }

    // Search Customers
    final custRows = await db.rawQuery(
      'SELECT name, mobile FROM customers WHERE name LIKE ? OR mobile LIKE ?',
      ['%$query%', '%$query%'],
    );
    for (var r in custRows) {
      searchResults.add({
        'module': 'Customer',
        'title': r['name'] as String,
        'subtitle': 'Phone: ${r['mobile']}',
      });
    }

    // Search Notes
    final noteRows = await db.rawQuery(
      'SELECT title, content FROM notes WHERE title LIKE ? OR content LIKE ?',
      ['%$query%', '%$query%'],
    );
    for (var r in noteRows) {
      searchResults.add({
        'module': 'Note',
        'title': r['title'] as String,
        'subtitle': r['content'] as String,
      });
    }

    setState(() {
      _results = searchResults;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: const InputDecoration(
            hintText: 'Search across Expenses, Customers, Notes, Income...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: _performSearch,
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(child: Text('Type to search across all LifeSync modules'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(item['module']![0]),
                        ),
                        title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(item['subtitle']!, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withAlpha(38),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(item['module']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
