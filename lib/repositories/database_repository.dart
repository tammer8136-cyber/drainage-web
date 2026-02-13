/// Реализация DataRepository для мобильных платформ (SQLite)
/// 
/// Обёртка над существующим DatabaseService
/// Обеспечивает единый интерфейс с StorageRepository

import '../services/database_service.dart';
import 'dart:convert';
import 'data_repository.dart';

class DatabaseRepository implements DataRepository {
  final DatabaseService _db = DatabaseService();
  
  @override
  Future<void> initialize() async {
    // DatabaseService инициализируется автоматически при первом обращении
    await _db.database;
  }
  
  @override
  Future<void> close() async {
    // SQLite закроется автоматически
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
    // DatabaseService ожидает Map для settings
    Map<String, dynamic>? settingsMap;
    if (settings != null) {
      try {
        settingsMap = jsonDecode(settings) as Map<String, dynamic>;
      } catch (e) {
        settingsMap = null;
      }
    }
    
    return await _db.createProject(
      name,
      notes: notes,
      settings: settingsMap,
    );
  }
  
  @override
  Future<List<Map<String, dynamic>>> getProjects() async {
    return await _db.getAllProjects();
  }
  
  @override
  Future<Map<String, dynamic>?> getProject(int id) async {
    return await _db.getProject(id);
  }
  
  @override
  Future<int> updateProject({
    required int id,
    String? name,
    String? notes,
    String? settings,
  }) async {
    // DatabaseService ожидает Map для settings
    Map<String, dynamic>? settingsMap;
    if (settings != null) {
      try {
        settingsMap = jsonDecode(settings) as Map<String, dynamic>;
      } catch (e) {
        settingsMap = null;
      }
    }
    
    return await _db.updateProject(
      id,
      name: name,
      notes: notes,
      settings: settingsMap,
    );
  }
  
  @override
  Future<int> deleteProject(int id) async {
    await _db.deleteProject(id);
    return 1; // Возвращаем 1 для совместимости с API
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
    // DatabaseService ожидает Map для inputData и resultData
    Map<String, dynamic> inputMap;
    Map<String, dynamic> resultMap;
    
    try {
      inputMap = jsonDecode(inputData) as Map<String, dynamic>;
      resultMap = jsonDecode(resultData) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Invalid JSON data: $e');
    }
    
    return await _db.addSection(
      projectId: projectId,
      sectionNumber: sectionNumber,
      name: name,
      inputData: inputMap,
      resultData: resultMap,
    );
  }
  
  @override
  Future<List<Map<String, dynamic>>> getSections(int projectId) async {
    return await _db.getProjectSections(projectId);
  }
  
  @override
  Future<Map<String, dynamic>?> getSection(int id) async {
    return await _db.getSection(id);
  }
  
  @override
  Future<int> updateSection({
    required int id,
    String? name,
    String? inputData,
    String? resultData,
  }) async {
    // DatabaseService ожидает Map для inputData и resultData
    Map<String, dynamic>? inputMap;
    Map<String, dynamic>? resultMap;
    
    if (inputData != null) {
      try {
        inputMap = jsonDecode(inputData) as Map<String, dynamic>;
      } catch (e) {
        inputMap = null;
      }
    }
    
    if (resultData != null) {
      try {
        resultMap = jsonDecode(resultData) as Map<String, dynamic>;
      } catch (e) {
        resultMap = null;
      }
    }
    
    return await _db.updateSection(
      id,
      name: name,
      inputData: inputMap,
      resultData: resultMap,
    );
  }
  
  @override
  Future<int> deleteSection(int id) async {
    await _db.deleteSection(id);
    return 1; // Возвращаем 1 для совместимости с API
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
    // DatabaseService не имеет insertHistory для истории проектов
    // Используем старый API для истории расчётов
    throw UnimplementedError('insertHistory not implemented - use projects instead');
  }
  
  @override
  Future<List<Map<String, dynamic>>> getHistory({int? limit}) async {
    // Возвращаем пустой список - история не используется
    return [];
  }
  
  @override
  Future<int> deleteHistory(int id) async {
    // История не используется
    return 0;
  }
  
  @override
  Future<int> clearHistory() async {
    // История не используется
    return 0;
  }
  
  // ============================================================================
  // УТИЛИТЫ
  // ============================================================================
  
  @override
  Future<Map<String, dynamic>> getStorageInfo() async {
    final projects = await getProjects();
    
    return {
      'type': 'SQLite',
      'projects_count': projects.length,
      'database_version': 3,
    };
  }
  
  @override
  Future<Map<String, dynamic>> getProjectStats(int projectId) async {
    return await _db.getProjectStats(projectId);
  }
  
  // ============================================================================
  // ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ (обёртки)
  // ============================================================================
  
  @override
  Future<List<Map<String, dynamic>>> getAllProjects() async {
    return await _db.getAllProjects();
  }
  
  @override
  Future<int> createProject(String name, {String? notes, Map<String, dynamic>? settings}) async {
    return await _db.createProject(name, notes: notes, settings: settings);
  }
  
  @override
  Future<List<Map<String, dynamic>>> getProjectSections(int projectId) async {
    return await _db.getProjectSections(projectId);
  }
  
  @override
  Future<int> addSection({
    required int projectId,
    required int sectionNumber,
    String? name,
    required Map<String, dynamic> inputData,
    required Map<String, dynamic> resultData,
  }) async {
    return await _db.addSection(
      projectId: projectId,
      sectionNumber: sectionNumber,
      name: name,
      inputData: inputData,
      resultData: resultData,
    );
  }
}
