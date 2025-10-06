import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tasktracker/pages/tasks.dart';

class Projects extends StatefulWidget {
  const Projects({super.key});

  @override
  State<Projects> createState() => _ProjectsState();
}

class _ProjectsState extends State<Projects> {
  final user = Supabase.instance.client.auth.currentUser;
  final projectController = TextEditingController();
  final searchController = TextEditingController();
  String _query = '';

  Future<void> _addProject() async {
    if (projectController.text.trim().isEmpty) return;

    await Supabase.instance.client.from('projects').insert({
      'name': projectController.text.trim(),
      'created_by': user!.id,
    });

    projectController.clear();
    setState(() {});
  }

  Future<(int done, int total)> _projectProgress(String projectId) async {
    try {
      final totalList = await Supabase.instance.client
          .from('tasks')
          .select('id')
          .eq('project_id', projectId);
      final doneList = await Supabase.instance.client
          .from('tasks')
          .select('id')
          .eq('project_id', projectId)
          .eq('status', 'done');
      final total = (totalList as List).length;
      final done = (doneList as List).length;
      return (done, total);
    } catch (_) {
      return (0, 0);
    }
  }

  Future<List<dynamic>> _fetchProjects() async {
    final response = await Supabase.instance.client
        .from('projects')
        .select()
        .eq('created_by', user!.id)
        .order('created_at', ascending: false);
    return response;
  }

  Future<void> _deleteProject(String projectId) async {
    await Supabase.instance.client
        .from('projects')
        .delete()
        .eq('id', projectId);

    setState(() {});
  }

  Future<void> _renameProject(String projectId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Project'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Project name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    await Supabase.instance.client
        .from('projects')
        .update({'name': result})
        .eq('id', projectId);
    if (mounted) setState(() {});
  }

  void _confirmDelete(String projectId, String projectName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Project"),
        content: Text(
            "Are you sure you want to delete \"$projectName\"?\n\n⚠️ This will also delete all tasks inside it."),
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
            onPressed: () {
              Navigator.pop(context);
              _deleteProject(projectId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Deleted project \"$projectName\""),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Projects",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),

              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search projects',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),

              // Project list
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _fetchProjects(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(
                        color: Colors.deepOrange,
                      ));
                    }

                    var projects = snapshot.data!;
                    if (_query.isNotEmpty) {
                      projects = projects
                          .where((p) => (p['name'] as String)
                              .toLowerCase()
                              .contains(_query))
                          .toList();
                    }
                    if (projects.isEmpty) {
                      return const Center(
                        child: Text(
                          'No projects yet',
                          style: TextStyle(color: Colors.deepOrange, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async => setState(() {}),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            child: ListTile(
                              title: Text(
                                project['name'],
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: FutureBuilder<(int done, int total)>(
                                  future: _projectProgress(project['id']),
                                  builder: (context, snap) {
                                    final done = snap.data?.$1 ?? 0;
                                    final total = snap.data?.$2 ?? 0;
                                    final progress = total == 0 ? 0.0 : done / total;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        LinearProgressIndicator(value: progress),
                                        const SizedBox(height: 4),
                                        Text('$done of $total tasks done',
                                            style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Rename',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _renameProject(project['id'], project['name']),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _confirmDelete(project['id'], project['name']),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Tasks(projectId: project['id']),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // Add project input (pinned at bottom)
              SafeArea(
                top: false,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: projectController,
                            decoration: InputDecoration(
                              labelText: 'New Project',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                const BorderSide(color: Colors.deepOrange, width: 2),
                              ),
                              floatingLabelStyle: TextStyle(color: Colors.deepOrange),
                            ),
                            onSubmitted: (_) => _addProject(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addProject,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
