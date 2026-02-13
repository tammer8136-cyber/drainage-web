import 'package:flutter/material.dart';
import 'dart:convert';
import '../repositories/repository_factory.dart';
import '../repositories/data_repository.dart';
import 'result_screen.dart';
import 'input_screen.dart';
import 'project_settings_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  
  const ProjectDetailScreen({
    Key? key,
    required this.projectId,
  }) : super(key: key);

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  DataRepository? _repo;
  Map<String, dynamic>? _project;
  List<Map<String, dynamic>> _sections = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initRepository();
  }

  Future<void> _initRepository() async {
    _repo = await RepositoryFactory.getInstance();
    await _loadProject();
  }

  Future<void> _loadProject() async {
    if (_repo == null) return;
    
    setState(() => _loading = true);
    
    final project = await _repo!.getProject(widget.projectId);
    final sections = await _repo!.getProjectSections(widget.projectId);
    final stats = await _repo!.getProjectStats(widget.projectId);
    
    setState(() {
      _project = project;
      _sections = sections;
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _addNewSection() async {
    // Получаем настройки проекта
    Map<String, dynamic>? projectSettings;
    if (_project!['settings'] != null) {
      projectSettings = jsonDecode(_project!['settings']);
    }
    
    final nextSectionNumber = _sections.length + 1;
    
    // Переход на экран ввода с параметрами проекта
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InputScreen(
          projectId: widget.projectId,
          sectionNumber: nextSectionNumber,
          projectSettings: projectSettings,
        ),
      ),
    );
    
    // Если участок добавлен, обновляем список
    if (result == true) {
      await _loadProject();
    }
  }

  Future<void> _openProjectSettings() async {
    Map<String, dynamic>? currentSettings;
    if (_project!['settings'] != null) {
      currentSettings = jsonDecode(_project!['settings']);
    }
    
    final newSettings = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectSettingsScreen(
          projectId: widget.projectId,
          currentSettings: currentSettings,
        ),
      ),
    );
    
    if (newSettings != null && _repo != null) {
      // Сохраняем новые настройки
      await _repo!.updateProject(
        id: widget.projectId,
        settings: jsonEncode(newSettings),
      );
      
      // Обновляем проект
      await _loadProject();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Настройки проекта сохранены')),
        );
      }
    }
  }

  Future<void> _deleteSection(int sectionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить участок?'),
        content: const Text('Участок будет удалён из проекта.'),
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
      await _repo!.deleteSection(sectionId);
      await _loadProject();
    }
  }

  void _viewSection(Map<String, dynamic> section) {
    try {
      final resultData = jsonDecode(section['result_data']);
      final resultJson = jsonEncode(resultData);
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(resultJson: resultJson),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки участка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Проект')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Проект')),
        body: const Center(child: Text('Проект не найден')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_project!['name']),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openProjectSettings,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewSection,
          ),
        ],
      ),
      body: Column(
        children: [
          // Статистика проекта
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ИТОГО ПО ПРОЕКТУ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Участков',
                      '${_stats?['section_count'] ?? 0}',
                      Icons.view_module,
                    ),
                    _buildStatItem(
                      'Средний слой',
                      '${(_stats?['avg_layer'] ?? 0).toStringAsFixed(1)} мм',
                      Icons.layers,
                    ),
                    _buildStatItem(
                      'Длина',
                      '${(_stats?['total_length'] ?? 0).toStringAsFixed(0)} м',
                      Icons.straighten,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Список участков
          Expanded(
            child: _sections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Нет участков в проекте',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addNewSection,
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить участок'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _sections.length,
                  itemBuilder: (context, index) {
                    final section = _sections[index];
                    
                    // Пытаемся получить статус и средний слой
                    String status = 'РЕШАЕМО';
                    double avgLayer = 0;
                    
                    try {
                      final resultData = jsonDecode(section['result_data']);
                      status = resultData['status'] ?? 'РЕШАЕМО';
                      
                      // Используем средний слой из результата (интегральный метод)
                      avgLayer = (resultData['average_layer'] as num?)?.toDouble() ?? 0.0;
                    } catch (e) {
                      print('Ошибка парсинга: $e');
                    }
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${section['section_number']}'),
                        ),
                        title: Text(
                          section['name'] ?? 'Участок ${section['section_number']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '$status • ${avgLayer.toStringAsFixed(1)} мм',
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility),
                                  SizedBox(width: 8),
                                  Text('Просмотр'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Удалить', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'view') {
                              _viewSection(section);
                            } else if (value == 'delete') {
                              _deleteSection(section['id']);
                            }
                          },
                        ),
                        onTap: () => _viewSection(section),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
