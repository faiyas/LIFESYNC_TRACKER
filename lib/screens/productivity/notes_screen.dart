import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/export_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _notes = [];
  bool _isLoading = true;
  int _lastDataVersion = -1;
  String _selectedFolder = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _folders = ['All', 'General', 'Work', 'Ideas', 'Voice Notes', 'Personal'];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadNotes();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('notes', orderBy: 'isPinned DESC, updatedAt DESC');
    setState(() {
      _notes = maps.map((e) => Note.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  List<Note> get _filteredNotes {
    return _notes.where((n) {
      if (_selectedFolder != 'All' && n.folder != _selectedFolder) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q) ||
            (n.tags?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();
  }

  Future<void> _addOrEditNoteDialog({Note? existingNote}) async {
    final titleController = TextEditingController(text: existingNote?.title ?? '');
    final contentController = TextEditingController(text: existingNote?.content ?? '');
    String selectedFolder = existingNote?.folder ?? 'General';
    String? audioPath = existingNote?.tags?.contains('audio:') == true
        ? existingNote!.tags!.split(',').firstWhere((t) => t.startsWith('audio:')).replaceFirst('audio:', '')
        : null;
    bool isPreviewMode = false;

    void insertMarkdownSyntax(String prefix, String suffix) {
      final text = contentController.text;
      final selection = contentController.selection;
      if (selection.start >= 0 && selection.end >= 0) {
        final newText = text.replaceRange(
          selection.start,
          selection.end,
          '$prefix${selection.textInside(text)}$suffix',
        );
        contentController.text = newText;
        contentController.selection = TextSelection.collapsed(
          offset: selection.start + prefix.length + (selection.end - selection.start),
        );
      } else {
        contentController.text = '$text$prefix$suffix';
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.edit_note_rounded, color: Colors.amber),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            existingNote == null ? 'Create Note' : 'Edit Note',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(isPreviewMode ? Icons.edit_outlined : Icons.visibility_outlined),
                            tooltip: isPreviewMode ? 'Edit Mode' : 'Markdown Preview',
                            onPressed: () => setModalState(() => isPreviewMode = !isPreviewMode),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Folder Dropdown
                  DropdownButtonFormField<String>(
                    value: _folders.contains(selectedFolder) && selectedFolder != 'All' ? selectedFolder : 'General',
                    decoration: InputDecoration(
                      labelText: 'Folder',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.folder_outlined),
                    ),
                    items: _folders
                        .where((f) => f != 'All')
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedFolder = v ?? 'General'),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Note Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Markdown Toolbar
                  if (!isPreviewMode)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          IconButton.outlined(
                            icon: const Icon(Icons.format_bold, size: 18),
                            tooltip: 'Bold',
                            onPressed: () => insertMarkdownSyntax('**', '**'),
                          ),
                          const SizedBox(width: 6),
                          IconButton.outlined(
                            icon: const Icon(Icons.format_italic, size: 18),
                            tooltip: 'Italic',
                            onPressed: () => insertMarkdownSyntax('*', '*'),
                          ),
                          const SizedBox(width: 6),
                          IconButton.outlined(
                            icon: const Icon(Icons.title, size: 18),
                            tooltip: 'Heading',
                            onPressed: () => insertMarkdownSyntax('# ', ''),
                          ),
                          const SizedBox(width: 6),
                          IconButton.outlined(
                            icon: const Icon(Icons.format_list_bulleted, size: 18),
                            tooltip: 'Bullet',
                            onPressed: () => insertMarkdownSyntax('- ', ''),
                          ),
                          const SizedBox(width: 6),
                          IconButton.outlined(
                            icon: const Icon(Icons.check_box_outlined, size: 18),
                            tooltip: 'Task Checkbox',
                            onPressed: () => insertMarkdownSyntax('- [ ] ', ''),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange.withOpacity(0.15),
                              foregroundColor: Colors.deepOrange,
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.mic, size: 16),
                            label: Text(audioPath == null ? 'Attach Audio' : 'Audio Attached'),
                            onPressed: () async {
                              final res = await FilePicker.platform.pickFiles(type: FileType.audio);
                              if (res != null && res.files.single.path != null) {
                                setModalState(() {
                                  audioPath = res.files.single.path;
                                  selectedFolder = 'Voice Notes';
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Content Editor vs Preview
                  if (isPreviewMode)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      constraints: const BoxConstraints(minHeight: 140, maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          contentController.text.isEmpty ? '(Empty Note)' : contentController.text,
                          style: const TextStyle(height: 1.4, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    TextField(
                      controller: contentController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        labelText: 'Content (supports Markdown formatting)...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        alignLabelWithHint: true,
                      ),
                    ),

                  if (audioPath != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.audiotrack, color: Colors.deepOrange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              audioPath!.split(RegExp(r'[\\/]')).last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.deepOrange),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                            onPressed: () => setModalState(() => audioPath = null),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) return;

                        final tagsBuffer = StringBuffer();
                        if (audioPath != null) {
                          tagsBuffer.write('audio:$audioPath');
                        }

                        final db = await AppDatabase.instance.database;

                        if (existingNote == null) {
                          final newNote = Note(
                            profileId: 'default_profile',
                            title: titleController.text.trim(),
                            content: contentController.text.trim(),
                            folder: selectedFolder,
                            tags: tagsBuffer.isEmpty ? null : tagsBuffer.toString(),
                          );
                          await db.insert('notes', newNote.toMap());
                        } else {
                          final updatedNote = Note(
                            id: existingNote.id,
                            profileId: existingNote.profileId,
                            title: titleController.text.trim(),
                            content: contentController.text.trim(),
                            folder: selectedFolder,
                            tags: tagsBuffer.isEmpty ? null : tagsBuffer.toString(),
                            isPinned: existingNote.isPinned,
                            isLocked: existingNote.isLocked,
                            createdAt: existingNote.createdAt,
                            updatedAt: DateTime.now().toIso8601String(),
                          );
                          await db.update('notes', updatedNote.toMap(), where: 'id = ?', whereArgs: [existingNote.id]);
                        }

                        try {
                          if (mounted) {
                            Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                          }
                        } catch (_) {}

                        if (mounted) Navigator.pop(context);
                        _loadNotes();
                      },
                      child: Text(
                        existingNote == null ? 'Save Note' : 'Update Note',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _togglePin(Note note) async {
    final db = await AppDatabase.instance.database;
    final updated = Note(
      id: note.id,
      profileId: note.profileId,
      title: note.title,
      content: note.content,
      folder: note.folder,
      tags: note.tags,
      isPinned: !note.isPinned,
      isLocked: note.isLocked,
      createdAt: note.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await db.update('notes', updated.toMap(), where: 'id = ?', whereArgs: [note.id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    _loadNotes();
  }

  Future<void> _deleteNote(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Markdown & Audio Notes'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditNoteDialog(),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('New Note'),
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search title, content, or tags...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // Folder category pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _folders.map((f) {
                final isSelected = _selectedFolder == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedFolder = f),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('No notes found'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.95,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final note = filtered[index];
                          final hasAudio = note.tags?.contains('audio:') == true;

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: note.isPinned
                                  ? const BorderSide(color: Colors.amber, width: 1.5)
                                  : BorderSide.none,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _addOrEditNoteDialog(existingNote: note),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            note.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: Icon(
                                            note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                            size: 16,
                                            color: note.isPinned ? Colors.amber : Colors.grey,
                                          ),
                                          onPressed: () => _togglePin(note),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Expanded(
                                      child: Text(
                                        note.content,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            if (hasAudio)
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                margin: const EdgeInsets.only(right: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.deepOrange.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(Icons.mic, size: 12, color: Colors.deepOrange),
                                              ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                note.folder,
                                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.share_outlined, size: 16, color: Colors.amber),
                                              onPressed: () => ExportService.shareText('${note.title}\n\n${note.content}'),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                              onPressed: () => _deleteNote(note.id),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
