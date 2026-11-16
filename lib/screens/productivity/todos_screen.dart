import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/app_notification_scheduler.dart';
import '../../services/dynamic_option_service.dart';
import '../../services/google_sheets_backup_service.dart';
import '../../widgets/dynamic_dropdown_field.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifesync_ui_components.dart';

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  List<Todo> _todos = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, pending, completed, high
  final TextEditingController _searchController = TextEditingController();
  int _lastDataVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadTodos();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;

    final maps = await db.query('todos', orderBy: 'isCompleted ASC, createdAt DESC');
    setState(() {
      _todos = maps.map((e) => Todo.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  Future<void> _addTodoDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String priority = 'medium';
    String selectedCategory = 'Personal';
    DateTime? dueDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                              color: const Color(0xFF6366F1).withAlpha(38),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_task_rounded, color: Color(0xFF6366F1)),
                          ),
                          const SizedBox(width: 12),
                          const Text('Add New Task 🎯', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.task_alt),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DynamicDropdownField(
                    type: DynamicOptionService.typeTodoCategory,
                    label: 'Category',
                    prefixIcon: Icons.folder_outlined,
                    initialValue: selectedCategory,
                    onChanged: (val) => setModalState(() => selectedCategory = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.flag_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low Priority 🟢')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium Priority 🟡')),
                      DropdownMenuItem(value: 'high', child: Text('High Priority 🔥')),
                    ],
                    onChanged: (v) => setModalState(() => priority = v!),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => dueDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey),
                          const SizedBox(width: 12),
                          Text(
                            dueDate != null
                                ? 'Due Date: ${DateFormat("dd MMM yyyy").format(dueDate!)}'
                                : 'Set Due Date (Optional)',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const Spacer(),
                          if (dueDate != null)
                            InkWell(
                              onTap: () => setModalState(() => dueDate = null),
                              child: const Icon(Icons.close, size: 18, color: Colors.grey),
                            )
                          else
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) return;

                        String activeProfile = 'default_profile';
                        try {
                          if (context.mounted) {
                            activeProfile = Provider.of<AppProvider>(context, listen: false).activeProfileId;
                          }
                        } catch (_) {}

                        final todo = Todo(
                          profileId: activeProfile,
                          title: titleController.text.trim(),
                          description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                          category: selectedCategory,
                          priority: priority,
                          dueDate: dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : null,
                        );

                        final db = await AppDatabase.instance.database;
                        await db.insert('todos', todo.toMap());
                        try {
                          if (context.mounted) {
                            Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                          }
                        } catch (_) {}
                        AppNotificationScheduler.instance.schedulePeriodicTaskReminders();
                        if (mounted) Navigator.pop(context);
                        _loadTodos();
                      },
                      child: const Text('Create Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Future<void> _editTodoDialog(Todo todo) async {
    final titleController = TextEditingController(text: todo.title);
    final descController = TextEditingController(text: todo.description ?? '');
    String priority = todo.priority;
    String selectedCategory = todo.category ?? 'Personal';
    DateTime? dueDate = todo.dueDate != null ? DateTime.tryParse(todo.dueDate!) : null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                              color: const Color(0xFF6366F1).withAlpha(38),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.edit_note_rounded, color: Color(0xFF6366F1)),
                          ),
                          const SizedBox(width: 12),
                          const Text('Edit Task ✏️', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.task_alt),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DynamicDropdownField(
                    type: DynamicOptionService.typeTodoCategory,
                    label: 'Category',
                    prefixIcon: Icons.folder_outlined,
                    initialValue: selectedCategory,
                    onChanged: (val) => setModalState(() => selectedCategory = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.flag_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low Priority 🟢')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium Priority 🟡')),
                      DropdownMenuItem(value: 'high', child: Text('High Priority 🔥')),
                    ],
                    onChanged: (v) => setModalState(() => priority = v!),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => dueDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey),
                          const SizedBox(width: 12),
                          Text(
                            dueDate != null
                                ? 'Due Date: ${DateFormat("dd MMM yyyy").format(dueDate!)}'
                                : 'Set Due Date (Optional)',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const Spacer(),
                          if (dueDate != null)
                            InkWell(
                              onTap: () => setModalState(() => dueDate = null),
                              child: const Icon(Icons.close, size: 18, color: Colors.grey),
                            )
                          else
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) return;

                        final updated = Todo(
                          id: todo.id,
                          profileId: todo.profileId,
                          title: titleController.text.trim(),
                          description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                          category: selectedCategory,
                          priority: priority,
                          dueDate: dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : null,
                          isCompleted: todo.isCompleted,
                          isPinned: todo.isPinned,
                          createdAt: todo.createdAt,
                        );

                        final db = await AppDatabase.instance.database;
                        await db.update('todos', updated.toMap(), where: 'id = ?', whereArgs: [todo.id]);
                        try {
                          if (context.mounted) {
                            Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                          }
                        } catch (_) {}
                        AppNotificationScheduler.instance.schedulePeriodicTaskReminders();
                        if (mounted) Navigator.pop(context);
                        _loadTodos();
                      },
                      child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Future<void> _toggleTodo(Todo todo) async {
    final db = await AppDatabase.instance.database;
    final updated = Todo(
      id: todo.id,
      profileId: todo.profileId,
      title: todo.title,
      description: todo.description,
      priority: todo.priority,
      category: todo.category,
      dueDate: todo.dueDate,
      isCompleted: !todo.isCompleted,
      isPinned: todo.isPinned,
      createdAt: todo.createdAt,
    );
    await db.update('todos', updated.toMap(), where: 'id = ?', whereArgs: [todo.id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    AppNotificationScheduler.instance.schedulePeriodicTaskReminders();
    _loadTodos();
  }

  Future<void> _deleteTodo(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('todos', where: 'id = ?', whereArgs: [id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    AppNotificationScheduler.instance.schedulePeriodicTaskReminders();
    _loadTodos();
  }

  Future<void> _sendToMyDay(Todo todo) async {
    try {
      final db = await AppDatabase.instance.database;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      String activeProfile = 'default_profile';
      try {
        if (mounted) {
          activeProfile = Provider.of<AppProvider>(context, listen: false).activeProfileId;
        }
      } catch (_) {}

      final myDayTask = MyDayTask(
        profileId: activeProfile,
        title: todo.title,
        notes: todo.description,
        priority: todo.priority.toLowerCase(),
        date: todayStr,
        durationMinutes: 30,
        category: 'general',
        schedulingType: 'flexible',
      );

      await db.insert('my_day_tasks', myDayTask.toMap());

      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Scheduled "${todo.title}" to My Day! ⏱️')),
              ],
            ),
            backgroundColor: const Color(0xFF0284C7),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending todo to My Day: $e');
    }
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.amber.shade700;
      default:
        return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalTasks = _todos.length;
    final completedTasks = _todos.where((t) => t.isCompleted).length;
    final pendingTasks = totalTasks - completedTasks;
    final highPriorityTasks = _todos.where((t) => t.priority.toLowerCase() == 'high' && !t.isCompleted).length;
    final completionPct = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

    final query = _searchController.text.toLowerCase();
    final filtered = _todos.where((t) {
      if (_filter == 'pending' && t.isCompleted) return false;
      if (_filter == 'completed' && !t.isCompleted) return false;
      if (_filter == 'high' && t.priority.toLowerCase() != 'high') return false;

      if (query.isNotEmpty) {
        final matchesTitle = t.title.toLowerCase().contains(query);
        final matchesDesc = t.description != null && t.description!.toLowerCase().contains(query);
        final matchesCat = t.category != null && t.category!.toLowerCase().contains(query);
        return matchesTitle || matchesDesc || matchesCat;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks & Productivity 📋'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined, color: Color(0xFF6366F1)),
            tooltip: 'Sync with Google Sheets Cloud',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing tasks to Google Sheets... ☁️'),
                  duration: Duration(seconds: 2),
                ),
              );
              final res = await GoogleSheetsBackupService.instance.backupNow();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Sync finished'),
                    backgroundColor: res['success'] == true ? Colors.green : Colors.redAccent,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Send Pending Tasks Push Reminder Now',
            onPressed: () async {
              await AppNotificationScheduler.instance.sendInstantTaskReminderNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔔 6-Hour Pending Task push reminder sent!'),
                    backgroundColor: Colors.indigo,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTodoDialog,
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New Task', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTodos,
        child: Column(
          children: [
            // Hero Task Productivity Banner Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                        'Productivity Overview',
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.positiveColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${(completionPct * 100).toStringAsFixed(0)}% Done',
                          style: const TextStyle(color: AppTheme.positiveColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      LifeSyncMetricPill(
                        label: 'Pending Tasks',
                        value: '$pendingTasks',
                        color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
                      ),
                      LifeSyncMetricPill(
                        label: 'Completed',
                        value: '$completedTasks',
                        color: AppTheme.positiveColor,
                      ),
                      LifeSyncMetricPill(
                        label: 'High Priority 🔥',
                        value: '$highPriorityTasks',
                        color: AppTheme.warningColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completionPct,
                      minHeight: 6,
                      backgroundColor: isDark ? Colors.white10 : Colors.black.withAlpha(15),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.positiveColor),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search tasks, description, categories...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchController.clear()),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            const SizedBox(height: 10),

            // Filter Tabs Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('All ($totalTasks)', 'all', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending ($pendingTasks)', 'pending', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed ($completedTasks)', 'completed', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('High Priority 🔥', 'high', isDark),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Tasks List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('No tasks found in this view.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final todo = filtered[index];
                            final priorityCol = _priorityColor(todo.priority);

                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => _editTodoDialog(todo),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  child: Row(
                                    children: [
                                      Transform.scale(
                                        scale: 1.1,
                                        child: Checkbox(
                                          value: todo.isCompleted,
                                          activeColor: const Color(0xFF10B981),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          onChanged: (_) => _toggleTodo(todo),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              todo.title,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                                                color: todo.isCompleted ? Colors.grey : null,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (todo.description != null && todo.description!.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                todo.description!,
                                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    todo.category ?? 'General',
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                                if (todo.dueDate != null) ...[
                                                  const SizedBox(width: 8),
                                                  Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade500),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    todo.dueDate!,
                                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: priorityCol.withAlpha(38),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          todo.priority.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: priorityCol,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      if (!todo.isCompleted)
                                        IconButton(
                                          onPressed: () => _sendToMyDay(todo),
                                          icon: const Icon(Icons.calendar_month_outlined, size: 20, color: Color(0xFF0284C7)),
                                          tooltip: 'Schedule to My Day',
                                        ),
                                      IconButton(
                                        onPressed: () => _deleteTodo(todo.id),
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                        tooltip: 'Delete Task',
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
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF6366F1),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _filter = value);
      },
    );
  }
}

