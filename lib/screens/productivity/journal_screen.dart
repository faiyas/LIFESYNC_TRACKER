import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<JournalEntry> _entries = [];
  bool _isLoading = true;
  int _lastDataVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadEntries();
      }
    } catch (_) {}
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('journal_entries', orderBy: 'date DESC');
    setState(() {
      _entries = maps.map((e) => JournalEntry.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  Future<void> _addEntryDialog() async {
    final contentController = TextEditingController();
    int mood = 3;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_calendar_rounded, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                const Text('Journal Reflection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('How are you feeling today?', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    final rating = index + 1;
                    final emojis = ['😡', '🙁', '😐', '🙂', '😄'];
                    final isSelected = mood == rating;
                    return InkWell(
                      onTap: () => setModalState(() => mood = rating),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.purple.withAlpha(38) : Colors.transparent,
                        ),
                        child: Text(emojis[index], style: const TextStyle(fontSize: 28)),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Write your thoughts...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.menu_book_outlined),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (contentController.text.isEmpty) return;

                  final entry = JournalEntry(
                    profileId: 'default_profile',
                    date: DateTime.now().toIso8601String().substring(0, 10),
                    mood: mood,
                    content: contentController.text,
                  );

                  final db = await AppDatabase.instance.database;
                  await db.insert('journal_entries', entry.toMap());
                  try {
                    if (mounted) {
                      Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                    }
                  } catch (_) {}
                  if (mounted) Navigator.pop(context);
                  _loadEntries();
                },
                child: const Text('Save Entry', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  String _moodEmoji(int mood) {
    switch (mood) {
      case 1:
        return '😡';
      case 2:
        return '🙁';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😄';
      default:
        return '😐';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Journal')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntryDialog,
        icon: const Icon(Icons.edit_calendar_rounded),
        label: const Text('New Entry'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('No journal entries yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(_moodEmoji(entry.mood), style: const TextStyle(fontSize: 24)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(entry.content, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
