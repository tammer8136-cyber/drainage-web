import 'package:flutter/material.dart';
import '../repositories/repository_factory.dart';
import '../repositories/data_repository.dart';
import 'project_detail_screen.dart';
import 'input_screen.dart';
import 'milling_input_screen.dart';
import 'milling_project_detail_screen.dart';
import '../services/milling/models/milling_models.dart';
import 'about_screen.dart';

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({Key? key}) : super(key: key);

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  DataRepository get _db => RepositoryFactory.instance;
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _loading = true);
    final projects = await _db.getAllProjects();
    setState(() {
      _projects = projects;
      _loading = false;
    });
  }

  /// Создание проекта — сначала выбор типа, затем своя форма для каждого.
  Future<void> _createProject() async {
    final kind = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Новый проект'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'drainage'),
            child: const ListTile(
              leading: Icon(Icons.water_drop, color: Colors.blue),
              title: Text('Дренаж'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'milling'),
            child: ListTile(
              leading: Icon(Icons.construction, color: Colors.amber.shade700),
              title: const Text('Фреза'),
            ),
          ),
        ],
      ),
    );

    if (kind == null) return;
    if (kind == 'milling') {
      await _createMillingProject();
    } else {
      await _createDrainageProject();
    }
  }

  Future<void> _createMillingProject() async {
    final nameController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый проект — фреза'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Название проекта'),
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

    if (ok == true && nameController.text.isNotEmpty) {
      // Настройки фрезы стартуют с дефолтных и правятся внутри проекта —
      // режим отметок здесь не спрашиваем: фреза всегда считается по
      // отсчётам рейки.
      final projectId = await _db.createProject(
        nameController.text,
        kind: 'milling',
        settings: MillingSettings.defaults().toJson(),
      );
      await _loadProjects();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MillingProjectDetailScreen(projectId: projectId),
          ),
        ).then((_) => _loadProjects());
      }
    }
  }

  Future<void> _createDrainageProject() async {
    final nameController = TextEditingController();
    final giController = TextEditingController();
    String elevationMode = 'rod'; // 'rod' | 'absolute'
    String giMode = 'auto'; // 'auto' | 'manual' — только если elevationMode == 'absolute'

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Новый проект'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название проекта',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Как вводить отметки',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Задаётся один раз, сменить нельзя',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('По рейке (как обычно)'),
                  value: 'rod',
                  groupValue: elevationMode,
                  onChanged: (v) => setDialogState(() => elevationMode = v!),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Абсолютные отметки'),
                  value: 'absolute',
                  groupValue: elevationMode,
                  onChanged: (v) => setDialogState(() => elevationMode = v!),
                ),
                if (elevationMode == 'absolute') ...[
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Горизонт автоматически'),

                    value: 'auto',
                    groupValue: giMode,
                    onChanged: (v) => setDialogState(() => giMode = v!),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Горизонт вручную'),
                    value: 'manual',
                    groupValue: giMode,
                    onChanged: (v) => setDialogState(() => giMode = v!),
                  ),
                  if (giMode == 'manual')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: giController,
                        decoration: const InputDecoration(
                          labelText: 'Горизонт (ГИ), м',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                ],
              ],
            ),
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
      ),
    );
    
    if (result == true && nameController.text.isNotEmpty) {
      final Map<String, dynamic> settings = {
        'elevationMode': elevationMode,
      };
      if (elevationMode == 'absolute') {
        settings['giMode'] = giMode;
        if (giMode == 'manual') {
          final giMeters = double.tryParse(giController.text);
          settings['gi'] = giMeters != null ? giMeters * 1000.0 : null;
        } else {
          settings['gi'] = null; // фиксируется по первому сохранённому участку
        }
      }

      final projectId = await _db.createProject(nameController.text, settings: settings);
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
    
    if (confirmed == true) {
      await _db.deleteProject(id);
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
                final isMillingProject = project['kind'] == 'milling';
                return FutureBuilder<Map<String, dynamic>>(
                  // Сводка считается по-разному: у фрезы нет «среднего
                  // слоя», там срез.
                  future: isMillingProject
                      ? _db.getMillingProjectStats(project['id'])
                      : _db.getProjectStats(project['id']),
                  builder: (context, snapshot) {
                    final stats = snapshot.data;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: Icon(
                          project['kind'] == 'milling'
                              ? Icons.construction
                              : Icons.water_drop,
                          size: 40,
                          color: project['kind'] == 'milling'
                              ? Colors.amber.shade700
                              : Colors.blue,
                        ),
                        title: Text(
                          project['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: stats != null
                          ? Text(
                              isMillingProject
                                  ? '${stats['section_count']} участков • '
                                    'срез ${stats['avg_cut'].toStringAsFixed(0)} мм'
                                  : '${stats['section_count']} участков • '
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
                          final isMilling = project['kind'] == 'milling';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => isMilling
                                  ? MillingProjectDetailScreen(
                                      projectId: project['id'])
                                  : ProjectDetailScreen(
                                      projectId: project['id']),
                            ),
                          ).then((_) => _loadProjects());
                        },
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'milling',
            backgroundColor: Colors.amber.shade700,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MillingInputScreen(),
                ),
              );
            },
            icon: const Icon(Icons.construction),
            label: const Text('Фреза'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'quickCalc',
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
        ],
      ),
    );
  }
}
