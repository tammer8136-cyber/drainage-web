/// Сервис для определения платформы выполнения
/// 
/// Используется для выбора правильной реализации хранилища данных
import 'package:flutter/foundation.dart' show kIsWeb;

class PlatformService {
  /// Запущено ли приложение в Web браузере
  static bool get isWeb => kIsWeb;
  
  /// Запущено ли на мобильной платформе (Android/iOS)
  static bool get isMobile => !kIsWeb;
  
  /// Тип используемого хранилища данных
  static String get storageType => isWeb ? 'localStorage' : 'SQLite';
  
  /// Для отладки
  static String get platformName {
    if (isWeb) return 'Web';
    return 'Mobile';
  }
  
  /// Поддерживается ли нативное сохранение файлов
  static bool get supportsNativeFileSaving => !isWeb;
  
  /// Нужно ли использовать веб-специфичный PDF экспорт
  static bool get useWebPdfExport => isWeb;
}
