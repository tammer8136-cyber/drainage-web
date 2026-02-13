/// Модуль drainage_core - Типы и константы
/// Часть системы расчёта дренажного профиля

class DrainageTypes {
  /// Минимальный уклон (мм/м)
  static const double kMin = 3.0;
  
  /// Шаг генерации P_set (мм)
  static const int delta = 5;
  
  /// Желаемый слой по умолчанию (мм)
  static const double defaultDesiredLayer = 50.0;
  
  /// Допуски слоёв для каждого типа лотка
  /// Формат: [минимум, максимум] в мм
  static const Map<String, List<int>> tolerance = {
    'PR': [0, 0],      // Примыкание
    'P':  [-10, 0],    // Понижение пешеходное
    'O':  [35, 70],    // Обычная точка
    'V':  [50, 70],    // Водораздел
    'DK': [35, 40],    // Дождевой колодец
    'K':  [60, 130],   // Карта (канализация)
  };
  
  /// Допустимые типы лотков
  static const Set<String> validTypes = {
    'PR', 'P', 'O', 'V', 'DK', 'K'
  };
}
