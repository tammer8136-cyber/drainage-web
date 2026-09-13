/// Модуль drainage_core - Типы и константы
/// Часть системы расчёта дренажного профиля

class DrainageTypes {
  /// Минимальный уклон (мм/м)
  static const double kMin = 3.6;
  
  /// Шаг генерации P_set (мм)
  static const int delta = 5;
  
  /// Желаемый слой по умолчанию (мм)
  static const double defaultDesiredLayer = 50.0;

  /// H2 (плавающий водораздел) по умолчанию выключен
  static const bool defaultUseH2 = false;

  /// Минимальная толщина нижнего слоя асфальта в карте (K/VK/DKK) — мм.
  /// Верхний слой в карте — до desiredLayer, весь излишек сверх
  /// (desiredLayer + kartaLowerLayerMin) уходит в нижний слой.
  static const double kartaLowerLayerMin = 20.0;
  
  /// Допуски слоёв для каждого типа лотка
  /// Формат: [минимум, максимум] в мм
  static const Map<String, List<int>> tolerance = {
    'PR':  [0, 0],      // Примыкание
    'P':   [-10, 0],    // Понижение пешеходное
    'O':   [35, 70],    // Обычная точка
    'V':   [50, 50],    // Водораздел
    'DK':  [35, 40],    // Дождевой колодец
    'K':   [60, 130],   // Карта (канализация)
    'VK':  [60, 130],   // Водораздел карта
    'DKK': [60, 130],   // Дождевой колодец карта
  };
  
  /// Допустимые типы лотков
  static const Set<String> validTypes = {
    'PR', 'P', 'O', 'V', 'DK', 'K', 'VK', 'DKK'
  };

  /// Типы, которые являются водоразделом
  static const Set<String> watershedTypes = {'V', 'VK'};

  /// Типы, где слой выбирается алгоритмом свободно (не диктуется соседней
  /// конструкцией) — используется в штрафе за неравномерность слоя
  /// (rate-of-change), который применяется только между такими точками.
  static const Set<String> freeLayerTypes = {'O', 'V', 'DK'};
}
