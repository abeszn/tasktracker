import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class Tasks extends StatefulWidget {
  final String projectId;
  const Tasks({super.key, required this.projectId});

  @override
  State<Tasks> createState() => _TasksState();
}

class _TasksState extends State<Tasks> {
  final taskController = TextEditingController();
  final user = Supabase.instance.client.auth.currentUser;
  String _filter = 'all'; // all, todo, in_progress, done
  final _dateFmt = DateFormat('yMMMd');

  Future<void> _addTask() async {
    if (taskController.text.trim().isEmpty) return;

    await Supabase.instance.client.from('tasks').insert({
      'title': taskController.text.trim(),
      'project_id': widget.projectId,
      'assigned_to': user!.id,
      'status': 'todo',
    });

    taskController.clear();
    setState(() {}); // Refresh list
  }

  Color _priorityColor(String? p) {
    switch (p) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.teal;
      default:
        return Colors.orange; // medium or null
    }
  }

  Future<void> _setPriority(String taskId, String priority) async {
    await Supabase.instance.client
        .from('tasks')
        .update({'priority': priority})
        .eq('id', taskId);
    if (mounted) setState(() {});
  }

  Future<void> _setDueDate(String taskId) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    await Supabase.instance.client
        .from('tasks')
        .update({'due_date': picked.toIso8601String()})
        .eq('id', taskId);
    if (mounted) setState(() {});
  }

  Future<void> _clearDueDate(String taskId) async {
    await Supabase.instance.client
        .from('tasks')
        .update({'due_date': null})
        .eq('id', taskId);
    if (mounted) setState(() {});
  }

  Future<void> _persistOrder(List<dynamic> tasks) async {
    for (var i = 0; i < tasks.length; i++) {
      final id = tasks[i]['id'];
      try {
        await Supabase.instance.client
            .from('tasks')
            .update({'sort_order': i + 1})
            .eq('id', id);
      } catch (_) {
        // ignore
      }
    }
  }

  Future<List<dynamic>> _fetchSubtasks(String taskId) async {
    try {
      final res = await Supabase.instance.client
          .from('subtasks')
          .select()
          .eq('task_id', taskId)
          .order('created_at', ascending: false);
      return res;
    } catch (_) {
      return [];
    }
  }

  Future<void> _toggleSubtask(String subId, String status) async {
    final next = status == 'done' ? 'todo' : 'done';
    await Supabase.instance.client
        .from('subtasks')
        .update({'status': next})
        .eq('id', subId);
    if (mounted) setState(() {});
  }

  Future<void> _addSubtask(String taskId, String title) async {
    if (title.trim().isEmpty) return;
    await Supabase.instance.client
        .from('subtasks')
        .insert({'task_id': taskId, 'title': title.trim()});
    if (mounted) setState(() {});
  }

  Future<void> _deleteSubtask(String subId) async {
    await Supabase.instance.client.from('subtasks').delete().eq('id', subId);
    if (mounted) setState(() {});
  }

  void _openSubtasksSheet(Map task) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subtasks for "${task['title']}"',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: _fetchSubtasks(task['id']),
                    builder: (context, snapshot) {
                      final list = snapshot.data ?? [];
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final sub = list[i];
                          return ListTile(
                            leading: Checkbox(
                              value: sub['status'] == 'done',
                              onChanged: (_) =>
                                  _toggleSubtask(sub['id'], sub['status']),
                            ),
                            title: Text(sub['title']),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteSubtask(sub['id']),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration:
                        const InputDecoration(hintText: 'New subtask'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        await _addSubtask(task['id'], controller.text);
                        controller.clear();
                      },
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<dynamic>> _fetchTasks() async {
    final response = await Supabase.instance.client
        .from('tasks')
        .select()
        .eq('project_id', widget.projectId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);
    if (_filter == 'all') return response;
    return response.where((t) => t['status'] == _filter).toList();
  }

  Future<void> _updateStatus(String taskId, String status) async {
    await Supabase.instance.client
        .from('tasks')
        .update({'status': status})
        .eq('id', taskId);
    setState(() {});
  }

  Future<void> _deleteTask(String taskId, String taskTitle) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Task"),
        content: Text("Are you sure you want to delete \"$taskTitle\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client
                  .from('tasks')
                  .delete()
                  .eq('id', taskId);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Task \"$taskTitle\" deleted"),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'in_progress':
        return Colors.orange;
      case 'done':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _editTaskTitle(String id, String current) async {
    final controller = TextEditingController(text: current);
    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Task title'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (updated == null || updated.isEmpty) return;
    await Supabase.instance.client
        .from('tasks')
        .update({'title': updated})
        .eq('id', id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Back + Title + Filters (centered)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back,
                            color: Theme.of(context).colorScheme.primary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'Tasks',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('All')),
                          ButtonSegment(value: 'todo', label: Text('To do')),
                          ButtonSegment(
                              value: 'in_progress', label: Text('In progress')),
                          ButtonSegment(value: 'done', label: Text('Done')),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (s) =>
                            setState(() => _filter = s.first),
                        showSelectedIcon: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Task List
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _fetchTasks(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child:
                        CircularProgressIndicator(color: Colors.deepOrange));
                  }

                  final tasks = List<Map<String, dynamic>>.from(snapshot.data!);
                  if (tasks.isEmpty) {
                    return const Center(
                      child: Text(
                        'No Tasks yet',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: ReorderableListView.builder(
                      itemCount: tasks.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = tasks.removeAt(oldIndex);
                        tasks.insert(newIndex, item);
                        setState(() {});
                        await _persistOrder(tasks);
                      },
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return Dismissible(
                          key: ValueKey(task['id']),
                          background: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            await _deleteTask(task['id'], task['title']);
                            return false;
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: _statusColor(task['status']),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onLongPress: () => _editTaskTitle(
                                          task['id'], task['title']),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task['title'],
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              if (task['priority'] != null)
                                                Chip(
                                                  label: Text(
                                                      'Priority: ${task['priority']}'),
                                                  visualDensity:
                                                  VisualDensity.compact,
                                                  materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                                  side: BorderSide.none,
                                                  backgroundColor:
                                                  _priorityColor(
                                                      task['priority'])
                                                      .withOpacity(0.15),
                                                  labelStyle: TextStyle(
                                                      color: _priorityColor(
                                                          task['priority'])),
                                                ),
                                              if (task['due_date'] != null)
                                                Chip(
                                                  label: Text(
                                                      'Due ${_dateFmt.format(DateTime.parse(task['due_date']))}'),
                                                  visualDensity:
                                                  VisualDensity.compact,
                                                  materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DropdownButton<String>(
                                    value: task['status'],
                                    underline: Container(),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'todo', child: Text('To Do')),
                                      DropdownMenuItem(
                                          value: 'in_progress',
                                          child: Text('In Progress')),
                                      DropdownMenuItem(
                                          value: 'done', child: Text('Done')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        _updateStatus(task['id'], val);
                                      }
                                    },
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      switch (value) {
                                        case 'p_low':
                                          return _setPriority(
                                              task['id'], 'low');
                                        case 'p_med':
                                          return _setPriority(
                                              task['id'], 'medium');
                                        case 'p_high':
                                          return _setPriority(
                                              task['id'], 'high');
                                        case 'due_set':
                                          return _setDueDate(task['id']);
                                        case 'due_clear':
                                          return _clearDueDate(task['id']);
                                        case 'subs':
                                          return _openSubtasksSheet(task);
                                        case 'del':
                                          return _deleteTask(
                                              task['id'], task['title']);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                          value: 'p_low',
                                          child: Text('Priority: Low')),
                                      PopupMenuItem(
                                          value: 'p_med',
                                          child: Text('Priority: Medium')),
                                      PopupMenuItem(
                                          value: 'p_high',
                                          child: Text('Priority: High')),
                                      PopupMenuDivider(),
                                      PopupMenuItem(
                                          value: 'due_set',
                                          child: Text('Set due date')),
                                      PopupMenuItem(
                                          value: 'due_clear',
                                          child: Text('Clear due date')),
                                      PopupMenuDivider(),
                                      PopupMenuItem(
                                          value: 'subs',
                                          child: Text('Manage subtasks')),
                                      PopupMenuDivider(),
                                      PopupMenuItem(
                                          value: 'del', child: Text('Delete')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Input at bottom
            SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: taskController,
                          decoration: InputDecoration(
                            labelText: 'New Task',
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                  color: Colors.deepOrange, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            floatingLabelStyle:
                            const TextStyle(color: Colors.deepOrange),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                  color: Colors.deepOrange, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onSubmitted: (_) => _addTask(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          Theme.of(context).colorScheme.primary,
                          foregroundColor:
                          Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Add'),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
