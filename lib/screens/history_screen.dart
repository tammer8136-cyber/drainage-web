import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/repository_factory.dart';
import '../repositories/data_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DataRepository? _repo;
  List<Map<String, dynamic>> projects = [];
  bool isLoading = true;

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
    
    setState(() {
      isLoading = true;
    });
    
    final loadedProjects = await _repo!.getAllProjects();
    
    setState(() {
      projects = loadedProjects;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История проектов'),
        actions: [
          if (projects.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAll,
              tooltip: 'Очистить всё',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : projects.isEmpty
              ? _buildEmptyState()
              : _buildProjectsList(),
    );
  }
  
  // Пустое состояние
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'История пуста',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Сохранённые расчёты появятся здесь',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
  
  // Список проектов
  Widget _buildProjectsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return _buildProjectCard(project);
      },
    );
  }
  
  // Карточка проекта
  Widget _buildProjectCard(Map<String, dynamic> project) {
    final id = project['id'] as int;
    final name = project['name'] as String;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(project['created_at'] as int);
    final status = project['status'] as String;
    
    final isSuccess = status == 'РЕШАЕМО';
    
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSuccess ? Colors.green : Colors.grey,
          child: Icon(
            isSuccess ? Icons.check : Icons.description,
            color: Colors.white,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Статус: $status'),
            Text(
              DateFormat('dd.MM.yyyy HH:mm').format(createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.open_in_new),
                  SizedBox(width: 8),
                  Text('Открыть'),
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
            if (value == 'delete') {
              _deleteProject(id);
            } else if (value == 'open') {
              _openProject(project);
            }
          },
        ),
        onTap: () => _openProject(project),
      ),
    );
  }
  
  // Открыть проект
  void _openProject(Map<String, dynamic> project) {
    // TODO: Загрузить данные проекта и перейти на экран ввода или результата
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Функция в разработке')),
    );
  }
  
  // Удалить проект
  Future<void> _deleteProject(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить проект?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ОТМЕНА'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && _repo != null) {
      if (!mounted) return;
      await _repo!.deleteProject(id);
      _loadProjects();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Проект удалён')),
        );
      }
    }
  }
  
  // Очистить всё
  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text('Все сохранённые проекты будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ОТМЕНА'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ОЧИСТИТЬ'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && _repo != null) {
      if (!mounted) return;
      await _repo!.clearHistory();
      _loadProjects();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('История очищена')),
        );
      }
    }
  }
}
