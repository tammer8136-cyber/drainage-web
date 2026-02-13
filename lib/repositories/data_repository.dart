/// Абстрактный репозиторий для работы с данными
/// 
/// Определяет единый интерфейс для работы с проектами, участками и историей.
/// Реализации: DatabaseRepository (Android) и StorageRepository (Web)

abstract class DataRepository {
  // ============================================================================
  // ПРОЕКТЫ
  // ============================================================================
  
  /// Создать новый проект
  Future<int> insertProject({
    required String name,
    String? notes,
    String? settings,
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
  Future<int> createProject(String name, {String? notes, Map<String, dynamic>? settings});
  
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
  });
}
