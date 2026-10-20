import 'package:flutter/material.dart';
import 'dart:convert';

import '../repositories/repository_factory.dart';
import '../repositories/data_repository.dart';
import '../services/milling/models/milling_models.dart';
import 'milling_input_screen.dart';
import 'milling_result_screen.dart';
import 'milling_settings_screen.dart';

/// Проект фрезы: список участков, сводка, настройки проекта.
class MillingProjectDetailScreen extends StatefulWidget {
  final int projectId;

  const MillingProjectDetailScreen({super.key, required this.projectId});

  @override
  State<MillingProjectDetailScreen> createState() =>
      _MillingProjectDetailScreenState();
}

class _MillingProjectDetailScreenState extends State<MillingProjectDetailScreen> {
  DataRepository get _db => RepositoryFactory.instance;
  Map<String, dynamic>? _project;
  List<Map<String, dynamic>> _sections = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final project = await _db.getProject(widget.projectId);
    final sections = await _db.getProjectSections(widget.projectId);
    final stats = await _db.getMillingProjectStats(widget.projectId);
    setState(() {
      _project = project;
      _sections = sections;
      _stats = stats;
      _loading = false;
    });
  }

  MillingSettings get _settings {
    if (_project?['settings'] != null) {
      try {
        return MillingSettings.fromJson(
          jsonDecode(_project!['settings']) as Map<String, dynamic>,
        );
      } catch (_) {
        return MillingSettings.defaults();
      }
    }
    return MillingSettings.defaults();
  }

  Future<void> _addSection() async {
    final next = _sections.length + 1;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MillingInputScreen(
          projectId: widget.projectId,
          sectionNumber: next,
          projectSettings: _settings,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openSettings() async {
    final updated = await Navigator.push<MillingSettings>(
      context,
      MaterialPageRoute(
        builder: (context) => MillingSettingsScreen(current: _settings),
      ),
    );
    if (updated != null) {
      await _db.updateProject(id: widget.projectId, settings: jsonEncode(updated.toJson()));
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Настройки проекта сохранены')),
        );
      }
    }
  }

  void _viewSection(Map<String, dynamic> section) {
    try {
      final resultJson = jsonEncode(jsonDecode(section['result_data']));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MillingResultScreen(resultJson: resultJson),
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

  Future<void> _deleteSection(int sectionId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить участок?'),
        content: Text('Участок "$name" будет удалён.'),
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
      await _db.deleteSection(sectionId);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_project?['name'] ?? 'Проект'),
        backgroundColor: Colors.amber.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Настройки проекта',
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Добавить участок',
            onPressed: _addSection,
          ),
        ],
      ),
      body: Column(
        children: [
          _statsCard(),
          Expanded(
            child: _sections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.construction, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Нет участков',
                            style: TextStyle(fontSize: 18, color: Colors.grey)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _addSection,
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить участок'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _sections.length,
                    itemBuilder: (context, i) => _sectionCard(_sections[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statsCard() {
    final s = _stats;
    return Card(
      margin: const EdgeInsets.all(12),
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Участков', '${s?['section_count'] ?? 0}', Icons.view_module),
                _stat('Средний срез',
                    '${(s?['avg_cut'] ?? 0).toStringAsFixed(0)} мм', Icons.content_cut),
                _stat('Длина',
                    '${(s?['total_length'] ?? 0).toStringAsFixed(0)} м', Icons.straighten),
              ],
            ),
            if ((s?['section_count'] ?? 0) > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Срез по проекту: ${(s?['min_cut'] ?? 0).toStringAsFixed(0)}'
                '–${(s?['max_cut'] ?? 0).toStringAsFixed(0)} мм',
                style: TextStyle(fontSize: 12, color: Colors.brown.shade700),
              ),
            ],
            if ((s?['parse_errors'] ?? 0) > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Не удалось прочитать ${s!['parse_errors']} уч. — '
                      'сводка выше по остальным',
                      style: const TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) => Column(
        children: [
          Icon(icon, color: Colors.brown.shade400),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );

  Widget _sectionCard(Map<String, dynamic> section) {
    String subtitle = '—';
    bool solvable = false;
    try {
      final r = jsonDecode(section['result_data']) as Map<String, dynamic>;
      solvable = r['status'] == 'РЕШАЕМО';
      final nodes = (r['nodes'] as List?) ?? [];
      if (nodes.isNotEmpty) {
        final cuts = nodes
            .map((n) => (n['cutLine'] as num).toDouble() - (n['fEdge'] as num).toDouble())
            .toList();
        final lo = cuts.reduce((a, b) => a < b ? a : b);
        final hi = cuts.reduce((a, b) => a > b ? a : b);
        final wd = r['watershed_index'] != null ? ' • водораздел' : '';
        subtitle = 'срез ${lo.toStringAsFixed(0)}–${hi.toStringAsFixed(0)} мм$wd';
      } else {
        subtitle = r['status'] as String? ?? '—';
      }
    } catch (_) {
      subtitle = 'ошибка чтения';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(
          solvable ? Icons.check_circle : Icons.error_outline,
          color: solvable ? Colors.green : Colors.red,
        ),
        title: Text(section['name'] ?? 'Участок ${section['section_number']}'),
        subtitle: Text(subtitle),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteSection(
            section['id'],
            section['name'] ?? 'Участок ${section['section_number']}',
          ),
        ),
        onTap: () => _viewSection(section),
      ),
    );
  }
}
