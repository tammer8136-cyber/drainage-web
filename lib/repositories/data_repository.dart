/// Абстрактный репозиторий для работы с данными
/// 
/// Определяет единый интерфейс для работы с проектами, участками и историей.
/// Реализации: DatabaseRepository (Android) и StorageRepository (Web)

import 'dart:convert';

abstract class DataRepository {
  // ============================================================================
  // ПРОЕКТЫ
  // ============================================================================
  
  /// Создать новый проект
  Future<int> insertProject({
    required String name,
    String? notes,
    String? settings,
    String kind = 'drainage',
  });
  
  /// Получить все проекты
  Future<List<Map<String, dynamic>>> getProjects();
  
  /// Получить проект по ID
  Future<Map<String, dynamic>?> getProject(int id);
  
  /// Обновить проект
  Future<int> updateProject({
    required int id,
    String? name,
    String? notes,
    String? settings,
  });
  
  /// Удалить проект (и все его участки)
  Future<int> deleteProject(int id);
  
  // ============================================================================
  // УЧАСТКИ ПРОЕКТА
  // ============================================================================
  
  /// Создать новый участок в проекте
  Future<int> insertSection({
    required int projectId,
    required int sectionNumber,
    String? name,
    required String inputData,
    required String resultData,
    String? settingsSnapshot,
  });
  
  /// Получить все участки проекта
  Future<List<Map<String, dynamic>>> getSections(int projectId);
  
  /// Получить участок по ID
  Future<Map<String, dynamic>?> getSection(int id);
  
  /// Обновить участок
  Future<int> updateSection({
    required int id,
    String? name,
    String? inputData,
    String? resultData,
    String? settingsSnapshot,
  });
  
  /// Удалить участок
  Future<int> deleteSection(int id);
  
  /// Получить следующий номер участка для проекта
  Future<int> getNextSectionNumber(int projectId);
  
  // ============================================================================
  // ИСТОРИЯ (для обратной совместимости)
  // ============================================================================
  
  /// Добавить запись в историю
  Future<int> insertHistory({
    required String inputData,
    required String resultData,
  });
  
  /// Получить историю расчётов
  Future<List<Map<String, dynamic>>> getHistory({int? limit});
  
  /// Удалить запись из истории
  Future<int> deleteHistory(int id);
  
  /// Очистить всю историю
  Future<int> clearHistory();
  
  // ============================================================================
  // УТИЛИТЫ
  // ============================================================================
  
  /// Инициализировать хранилище
  Future<void> initialize();
  
  /// Закрыть соединение (для SQLite)
  Future<void> close();
  
  /// Получить информацию о хранилище (для отладки)
  Future<Map<String, dynamic>> getStorageInfo();
  
  // ============================================================================
  // ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ (обёртки для совместимости)
  // ============================================================================
  
  /// Получить все проекты (alias для getProjects)
  Future<List<Map<String, dynamic>>> getAllProjects();
  
  /// Создать проект (упрощённый метод)
  Future<int> createProject(String name, {String? notes, Map<String, dynamic>? settings, String kind = 'drainage'});

  /// Статистика проекта фрезы: средний срез (по длине), диапазон, длина
  Future<Map<String, dynamic>> getMillingProjectStats(int projectId);
  
  /// Получить статистику проекта
  Future<Map<String, dynamic>> getProjectStats(int projectId);
  
  /// Получить участки проекта (alias для getSections)
  Future<List<Map<String, dynamic>>> getProjectSections(int projectId);
  
  /// Добавить участок (alias для insertSection с автоназванием)
  Future<int> addSection({
    required int projectId,
    required int sectionNumber,
    String? name,
    required Map<String, dynamic> inputData,
    required Map<String, dynamic> resultData,
    Map<String, dynamic>? settingsSnapshot,
  });
}

/// Статистика проекта фрезы по списку участков — ОДНА функция для обоих
/// хранилищ (SQLite и localStorage), чтобы цифры не расходились.
/// Средний срез — трапециями по длине, тем же методом, что и солвер.
Map<String, dynamic> millingStatsFromSections(List<Map<String, dynamic>> sections) {
  if (sections.isEmpty) {
    return {
      'section_count': 0,
      'avg_cut': 0.0,
      'min_cut': 0.0,
      'max_cut': 0.0,
      'total_length': 0.0,
      'parse_errors': 0,
    };
  }

  double weightedSum = 0.0;
  double totalLength = 0.0;
  double minCut = double.infinity;
  double maxCut = -double.infinity;
  int parseErrors = 0;

  for (final section in sections) {
    try {
      final raw = section['result_data'];
      final result = (raw is String ? jsonDecode(raw) : raw) as Map<String, dynamic>;
      final nodes = (result['nodes'] as List?) ?? [];
      if (nodes.isEmpty) continue;

      final alongs = nodes.map((n) => (n['along'] as num).toDouble()).toList();
      final cuts = nodes
          .map((n) => (n['cutLine'] as num).toDouble() - (n['fEdge'] as num).toDouble())
          .toList();

      for (final c in cuts) {
        if (c < minCut) minCut = c;
        if (c > maxCut) maxCut = c;
      }
      for (int i = 0; i < nodes.length - 1; i++) {
        final d = alongs[i + 1] - alongs[i];
        if (d <= 0) continue;
        weightedSum += (cuts[i] + cuts[i + 1]) / 2 * d;
        totalLength += d;
      }
    } catch (e) {
      parseErrors++;
    }
  }

  return {
    'section_count': sections.length,
    'avg_cut': totalLength > 0 ? weightedSum / totalLength : 0.0,
    'min_cut': minCut.isFinite ? minCut : 0.0,
    'max_cut': maxCut.isFinite ? maxCut : 0.0,
    'total_length': totalLength,
    'parse_errors': parseErrors,
  };
}
