import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseService {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await init();
    return _database!;
  }
  
  Future<Database> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'drainage_v2.db');
    
    return await openDatabase(
      path,
      version: 3,  // Увеличиваем версию для миграции
      onCreate: (db, version) async {
        // Таблица проектов
        await db.execute('''
          CREATE TABLE projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL,
            notes TEXT,
            settings TEXT
          )
        ''');
        
        // Таблица участков проекта
        await db.execute('''
          CREATE TABLE project_sections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            section_number INTEGER NOT NULL,
            name TEXT,
            input_data TEXT NOT NULL,
            result_data TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
          )
        ''');
        
        // Старая таблица для истории
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at INTEGER NOT NULL,
            input_data TEXT NOT NULL,
            result_data TEXT,
            status TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Миграция со старой версии
        if (oldVersion < 3) {
          // Проверяем существует ли колонка settings
          var result = await db.rawQuery('PRAGMA table_info(projects)');
          bool hasSettings = result.any((col) => col['name'] == 'settings');
          
          if (!hasSettings) {
            await db.execute('ALTER TABLE projects ADD COLUMN settings TEXT');
          }
        }
      },
    );
  }
  
  // ============================================================================
  // ПРОЕКТЫ
  // ============================================================================
  
  /// Создать новый проект
  Future<int> createProject(String name, {String? notes, Map<String, dynamic>? settings}) async {
    final db = await database;
    return await db.insert('projects', {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
      'notes': notes,
      'settings': settings != null ? jsonEncode(settings) : null,
    });
  }
  
  /// Получить все проекты
  Future<List<Map<String, dynamic>>> getAllProjects() async {
    final db = await database;
    return await db.query('projects', orderBy: 'created_at DESC');
  }
  
  /// Получить проект по ID
  Future<Map<String, dynamic>?> getProject(int id) async {
    final db = await database;
    final results = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }
  
  /// Обновить проект
  Future<int> updateProject(int id, {String? name, String? notes, Map<String, dynamic>? settings}) async {
    final db = await database;
    
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (notes != null) updates['notes'] = notes;
    if (settings != null) updates['settings'] = jsonEncode(settings);
    
    if (updates.isEmpty) return 0;
    
    return await db.update(
      'projects',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// Удалить проект (каскадно удалит все участки)
  Future<void> deleteProject(int id) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
    // Участки удалятся автоматически через ON DELETE CASCADE
  }
  
  // ============================================================================
  // УЧАСТКИ ПРОЕКТА
  // ============================================================================
  
  /// Добавить участок в проект
  Future<int> addSection({
    required int projectId,
    required int sectionNumber,
    String? name,
    required Map<String, dynamic> inputData,
    required Map<String, dynamic> resultData,
  }) async {
    final db = await database;
    return await db.insert('project_sections', {
      'project_id': projectId,
      'section_number': sectionNumber,
      'name': name ?? 'Участок $sectionNumber',
      'input_data': jsonEncode(inputData),
      'result_data': jsonEncode(resultData),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
  
  /// Получить все участки проекта
  Future<List<Map<String, dynamic>>> getProjectSections(int projectId) async {
    final db = await database;
    return await db.query(
      'project_sections',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'section_number ASC',
    );
  }
  
  /// Получить участок по ID
  Future<Map<String, dynamic>?> getSection(int id) async {
    final db = await database;
    final results = await db.query(
      'project_sections',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }
  
  /// Удалить участок
  Future<void> deleteSection(int id) async {
    final db = await database;
    await db.delete('project_sections', where: 'id = ?', whereArgs: [id]);
  }
  
  /// Обновить участок
  Future<int> updateSection(int id, {String? name, Map<String, dynamic>? inputData, Map<String, dynamic>? resultData}) async {
    final db = await database;
    
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (inputData != null) updates['input_data'] = jsonEncode(inputData);
    if (resultData != null) updates['result_data'] = jsonEncode(resultData);
    
    if (updates.isEmpty) return 0;
    
    return await db.update(
      'project_sections',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// Получить статистику проекта
  Future<Map<String, dynamic>> getProjectStats(int projectId) async {
    final sections = await getProjectSections(projectId);
    
    if (sections.isEmpty) {
      return {
        'section_count': 0,
        'avg_layer': 0.0,
        'total_length': 0.0,
      };
    }
    
    double weightedSum = 0.0;  // Сумма (средний_слой * длина)
    double totalLength = 0.0;
    
    for (final section in sections) {
      try {
        final resultData = jsonDecode(section['result_data']);
        final inputData = jsonDecode(section['input_data']);
        
        // Средний слой участка (из результата расчёта - интегральный метод)
        final double avgLayer = (resultData['average_layer'] as num?)?.toDouble() ?? 0.0;
        
        // Длина участка
        final List<double> L = (inputData['L'] as List).map((e) => (e as num).toDouble()).toList();
        final double length = L.reduce((a, b) => a + b);
        
        // Взвешенное среднее: (S1*L1 + S2*L2 + ...) / (L1+L2+...)
        weightedSum += avgLayer * length;
        totalLength += length;
      } catch (e) {
        print('Ошибка обработки участка: $e');
      }
    }
    
    return {
      'section_count': sections.length,
      'avg_layer': totalLength > 0 ? weightedSum / totalLength : 0.0,  // Взвешенное среднее
      'total_length': totalLength,
    };
  }
  
  // ============================================================================
  // ИСТОРИЯ (старая система, для совместимости)
  // ============================================================================
  
  /// Сохранить в историю (старый формат)
  Future<int> saveToHistory({
    required String inputData,
    String? resultData,
    required String status,
  }) async {
    final db = await database;
    
    return await db.insert('history', {
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'input_data': inputData,
      'result_data': resultData,
      'status': status,
    });
  }
  
  /// Получить всю историю
  Future<List<Map<String, dynamic>>> getAllHistory() async {
    final db = await database;
    return await db.query(
      'history',
      orderBy: 'created_at DESC',
    );
  }
  
  /// Очистить историю
  Future<int> clearHistory() async {
    final db = await database;
    return await db.delete('history');
  }
}
