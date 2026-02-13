/// Реализация DataRepository для Web (localStorage)
/// 
/// Использует shared_preferences для хранения данных в localStorage
/// Все данные хранятся в JSON формате

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_repository.dart';

class StorageRepository implements DataRepository {
  static const String _projectsKey = 'drainage_projects';
  static const String _sectionsKey = 'drainage_sections';
  static const String _historyKey = 'drainage_history';
  static const String _nextProjectIdKey = 'drainage_next_project_id';
  static const String _nextSectionIdKey = 'drainage_next_section_id';
  static const String _nextHistoryIdKey = 'drainage_next_history_id';
  
  SharedPreferences? _prefs;
  
  // ============================================================================
  // ИНИЦИАЛИЗАЦИЯ
  // ============================================================================
  
  @override
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Инициализируем счётчики если их нет
    if (!_prefs!.containsKey(_nextProjectIdKey)) {
      await _prefs!.setInt(_nextProjectIdKey, 1);
    }
    if (!_prefs!.containsKey(_nextSectionIdKey)) {
      await _prefs!.setInt(_nextSectionIdKey, 1);
    }
    if (!_prefs!.containsKey(_nextHistoryIdKey)) {
      await _prefs!.setInt(_nextHistoryIdKey, 1);
    }
  }
  
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('StorageRepository not initialized. Call initialize() first.');
    }
    return _prefs!;
  }
  
  @override
  Future<void> close() async {
    // Для localStorage не требуется закрытие
  }
  
  // ============================================================================
  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ============================================================================
  
  /// Получить следующий ID
  Future<int> _getNextId(String key) async {
    final currentId = prefs.getInt(key) ?? 1;
    await prefs.setInt(key, currentId + 1);
    return currentId;
  }
  
  /// Загрузить список из localStorage
  List<Map<String, dynamic>> _loadList(String key) {
    final jsonString = prefs.getString(key);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error loading $key: $e');
      return [];
    }
  }
  
  /// Сохранить список в localStorage
  Future<bool> _saveList(String key, List<Map<String, dynamic>> list) async {
    final jsonString = jsonEncode(list);
    return await prefs.setString(key, jsonString);
  }
  
  /// Получить текущую дату-время в ISO формате
  String _now() {
    return DateTime.now().toIso8601String();
  }
  
  // ============================================================================
  // ПРОЕКТЫ
  // ============================================================================
  
  @override
  Future<int> insertProject({
    required String name,
    String? notes,
    String? settings,
  }) async {
    final projects = _loadList(_projectsKey);
    final id = await _getNextId(_nextProjectIdKey);
    
    final project = {
      'id': id,
      'name': name,
      'created_at': _now(),
      'notes': notes,
      'settings': settings,
    };
    
    projects.add(project);
    await _saveList(_projectsKey, projects);
    
    return id;
  }
  
  @override
  Future<List<Map<String, dynamic>>> getProjects() async {
    return _loadList(_projectsKey);
  }
  
  @override
  Future<Map<String, dynamic>?> getProject(int id) async {
    final projects = _loadList(_projectsKey);
    try {
      return projects.firstWhere((p) => p['id'] == id);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<int> updateProject({
    required int id,
    String? name,
    String? notes,
    String? settings,
  }) async {
    final projects = _loadList(_projectsKey);
    final index = projects.indexWhere((p) => p['id'] == id);
    
    if (index == -1) return 0;
    
    if (name != null) projects[index]['name'] = name;
    if (notes != null) projects[index]['notes'] = notes;
    if (settings != null) projects[index]['settings'] = settings;
    
    await _saveList(_projectsKey, projects);
    return 1;
  }
  
  @override
  Future<int> deleteProject(int id) async {
    final projects = _loadList(_projectsKey);
    final initialLength = projects.length;
    
    projects.removeWhere((p) => p['id'] == id);
    await _saveList(_projectsKey, projects);
    
    // Также удаляем все участки этого проекта
    final sections = _loadList(_sectionsKey);
    sections.removeWhere((s) => s['project_id'] == id);
    await _saveList(_sectionsKey, sections);
    
    return initialLength - projects.length;
  }
  
  // ============================================================================
  // УЧАСТКИ
  // ============================================================================
  
  @override
  Future<int> insertSection({
    required int projectId,
    required int sectionNumber,
    String? name,
    required String inputData,
    required String resultData,
  }) async {
    final sections = _loadList(_sectionsKey);
    final id = await _getNextId(_nextSectionIdKey);
    
    final section = {
      'id': id,
      'project_id': projectId,
      'section_number': sectionNumber,
      'name': name,
      'input_data': inputData,
      'result_data': resultData,
      'created_at': _now(),
    };
    
    sections.add(section);
    await _saveList(_sectionsKey, sections);
    
    return id;
  }
  
  @override
  Future<List<Map<String, dynamic>>> getSections(int projectId) async {
    final sections = _loadList(_sectionsKey);
    return sections.where((s) => s['project_id'] == projectId).toList();
  }
  
  @override
  Future<Map<String, dynamic>?> getSection(int id) async {
    final sections = _loadList(_sectionsKey);
    try {
      return sections.firstWhere((s) => s['id'] == id);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<int> updateSection({
    required int id,
    String? name,
    String? inputData,
    String? resultData,
  }) async {
    final sections = _loadList(_sectionsKey);
    final index = sections.indexWhere((s) => s['id'] == id);
    
    if (index == -1) return 0;
    
    if (name != null) sections[index]['name'] = name;
    if (inputData != null) sections[index]['input_data'] = inputData;
    if (resultData != null) sections[index]['result_data'] = resultData;
    
    await _saveList(_sectionsKey, sections);
    return 1;
  }
  
  @override
  Future<int> deleteSection(int id) async {
    final sections = _loadList(_sectionsKey);
    final initialLength = sections.length;
    
    sections.removeWhere((s) => s['id'] == id);
    await _saveList(_sectionsKey, sections);
    
    return initialLength - sections.length;
  }
  
  @override
  Future<int> getNextSectionNumber(int projectId) async {
    final sections = await getSections(projectId);
    if (sections.isEmpty) return 1;
    
    final maxNumber = sections
        .map((s) => s['section_number'] as int)
        .reduce((a, b) => a > b ? a : b);
    
    return maxNumber + 1;
  }
  
  // ============================================================================
  // ИСТОРИЯ
  // ============================================================================
  
  @override
  Future<int> insertHistory({
    required String inputData,
    required String resultData,
  }) async {
    final history = _loadList(_historyKey);
    final id = await _getNextId(_nextHistoryIdKey);
    
    final record = {
      'id': id,
      'input_data': inputData,
      'result_data': resultData,
      'created_at': _now(),
    };
    
    history.add(record);
    await _saveList(_historyKey, history);
    
    return id;
  }
  
  @override
  Future<List<Map<String, dynamic>>> getHistory({int? limit}) async {
    var history = _loadList(_historyKey);
    
    // Сортируем по дате (новые первыми)
    history.sort((a, b) {
      final aDate = DateTime.parse(a['created_at'] as String);
      final bDate = DateTime.parse(b['created_at'] as String);
      return bDate.compareTo(aDate);
    });
    
    if (limit != null && history.length > limit) {
      history = history.sublist(0, limit);
    }
    
    return history;
  }
  
  @override
  Future<int> deleteHistory(int id) async {
    final history = _loadList(_historyKey);
    final initialLength = history.length;
    
    history.removeWhere((h) => h['id'] == id);
    await _saveList(_historyKey, history);
    
    return initialLength - history.length;
  }
  
  @override
  Future<int> clearHistory() async {
    await _saveList(_historyKey, []);
    return 1;
  }
  
  // ============================================================================
  // УТИЛИТЫ
  // ============================================================================
  
  @override
  Future<Map<String, dynamic>> getStorageInfo() async {
    final projects = _loadList(_projectsKey);
    final sections = _loadList(_sectionsKey);
    final history = _loadList(_historyKey);
    
    // Подсчитываем размер данных (примерно)
    final projectsSize = jsonEncode(projects).length;
    final sectionsSize = jsonEncode(sections).length;
    final historySize = jsonEncode(history).length;
    final totalSize = projectsSize + sectionsSize + historySize;
    
    return {
      'type': 'localStorage',
      'projects_count': projects.length,
      'sections_count': sections.length,
      'history_count': history.length,
      'total_size_bytes': totalSize,
      'total_size_kb': (totalSize / 1024).toStringAsFixed(2),
      'next_project_id': prefs.getInt(_nextProjectIdKey),
      'next_section_id': prefs.getInt(_nextSectionIdKey),
      'next_history_id': prefs.getInt(_nextHistoryIdKey),
    };
  }
  
  @override
  Future<Map<String, dynamic>> getProjectStats(int projectId) async {
    final sections = await getSections(projectId);
    
    if (sections.isEmpty) {
      return {
        'section_count': 0,
        'avg_layer': 0.0,
        'total_length': 0.0,
      };
    }
    
    double weightedSum = 0.0;
    double totalLength = 0.0;
    
    for (final section in sections) {
      try {
        final resultData = jsonDecode(section['result_data'] as String);
        final inputData = jsonDecode(section['input_data'] as String);
        
        final averageLayer = resultData['average_layer'];
        if (averageLayer != null) {
          final L = inputData['L'] as List;
          final sectionLength = L.fold<double>(0.0, (sum, l) => sum + (l as num).toDouble());
          
          weightedSum += averageLayer * sectionLength;
          totalLength += sectionLength;
        }
      } catch (e) {
        print('Error calculating stats for section ${section['id']}: $e');
      }
    }
    
    final avgLayer = totalLength > 0 ? weightedSum / totalLength : 0.0;
    
    return {
      'section_count': sections.length,
      'avg_layer': avgLayer,
      'total_length': totalLength,
    };
  }
  
  // ============================================================================
  // ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ (обёртки)
  // ============================================================================
  
  @override
  Future<List<Map<String, dynamic>>> getAllProjects() async {
    return await getProjects();
  }
  
  @override
  Future<int> createProject(String name, {String? notes, Map<String, dynamic>? settings}) async {
    return await insertProject(
      name: name,
      notes: notes,
      settings: settings != null ? jsonEncode(settings) : null,
    );
  }
  
  @override
  Future<List<Map<String, dynamic>>> getProjectSections(int projectId) async {
    return await getSections(projectId);
  }
  
  @override
  Future<int> addSection({
    required int projectId,
    required int sectionNumber,
    String? name,
    required Map<String, dynamic> inputData,
    required Map<String, dynamic> resultData,
  }) async {
    return await insertSection(
      projectId: projectId,
      sectionNumber: sectionNumber,
      name: name ?? 'Участок $sectionNumber',
      inputData: jsonEncode(inputData),
      resultData: jsonEncode(resultData),
    );
  }
}
