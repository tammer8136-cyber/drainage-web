/// Фабрика для создания правильного репозитория в зависимости от платформы
/// 
/// Web → StorageRepository (localStorage)
/// Android/iOS → DatabaseRepository (SQLite)

import '../services/platform_service.dart';
import 'data_repository.dart';
import 'storage_repository.dart';
import 'database_repository.dart';

class RepositoryFactory {
  static DataRepository? _instance;
  
  /// Получить единственный экземпляр репозитория (Singleton)
  static Future<DataRepository> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }
    
    // Создаём правильный репозиторий в зависимости от платформы
    if (PlatformService.isWeb) {
      _instance = StorageRepository();
    } else {
      _instance = DatabaseRepository();
    }
    
    // Инициализируем
    await _instance!.initialize();
    
    return _instance!;
  }
  
  /// Сбросить instance (для тестирования)
  static void reset() {
    _instance = null;
  }
  
  /// Получить информацию о текущем репозитории
  static Future<Map<String, dynamic>> getInfo() async {
    final repo = await getInstance();
    final info = await repo.getStorageInfo();
    info['platform'] = PlatformService.platformName;
    return info;
  }
}
