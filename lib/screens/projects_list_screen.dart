import 'package:flutter/material.dart';
import '../repositories/repository_factory.dart';
import '../repositories/data_repository.dart';
import 'project_detail_screen.dart';
import 'input_screen.dart';
import 'about_screen.dart';

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({Key? key}) : super(key: key);

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  DataRepository? _repo;
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initRepository();
  }

  Future<void> _initRepository() async {
    _repo = await RepositoryFactory.getInstance();
    await _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (_repo == null) return;
    
    setState(() => _loading = true);
    final projects = await _repo!.getProjects();
    setState(() {
      _projects = projects;
      _loading = false;
    });
  }

  Future<void> _createProject() async {
    final nameController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый проект'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Название проекта',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    
    if (result == true && nameController.text.isNotEmpty && _repo != null) {
      final projectId = await _repo!.createProject(nameController.text);
      await _loadProjects();
      
      // Переход к новому проекту
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailScreen(projectId: projectId),
          ),
        ).then((_) => _loadProjects());
      }
    }
  }

  Future<void> _deleteProject(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить проект?'),
        content: Text('Проект "$name" и все его участки будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && _repo != null) {
      await _repo!.deleteProject(id);
      await _loadProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Проекты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createProject,
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _projects.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Нет проектов',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _createProject,
                    icon: const Icon(Icons.add),
                    label: const Text('Создать проект'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                final project = _projects[index];
                return FutureBuilder<Map<String, dynamic>>(
                  future: _repo?.getProjectStats(project['id']),
                  builder: (context, snapshot) {
                    final stats = snapshot.data;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.folder, size: 40, color: Colors.blue),
                        title: Text(
                          project['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: stats != null
                          ? Text(
                              '${stats['section_count']} участков • '
                              '${stats['avg_layer'].toStringAsFixed(0)} мм',
                            )
                          : const Text('Загрузка...'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteProject(
                            project['id'],
                            project['name'],
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProjectDetailScreen(
                                projectId: project['id'],
                              ),
                            ),
                          ).then((_) => _loadProjects());
                        },
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InputScreen(),
            ),
          );
        },
        icon: const Icon(Icons.calculate),
        label: const Text('Быстрый расчёт'),
      ),
    );
  }
}
