/// Модуль drainage_core - Настройки расчёта
/// Часть системы расчёта дренажного профиля

import 'types.dart';

class DrainageSettings {
  /// Допуски слоёв для каждого типа лотка
  Map<String, List<int>> tolerance;
  
  /// Минимальный уклон (мм/м)
  double kMin;
  
  /// Шаг генерации P_set (мм)
  int delta;
  
  /// Желаемый слой по умолчанию (мм)
  double desiredLayer;
  
  /// Использовать H3 алгоритм (прямой уклон)
  bool useH3;
  
  /// Сравнивать все методы и выбирать лучший
  bool compareAllMethods;
  
  DrainageSettings({
    Map<String, List<int>>? tolerance,
    double? kMin,
    int? delta,
    double? desiredLayer,
    bool? useH3,
    bool? compareAllMethods,
  })  : tolerance = tolerance ?? Map.from(DrainageTypes.tolerance),
        kMin = kMin ?? DrainageTypes.kMin,
        delta = delta ?? DrainageTypes.delta,
        desiredLayer = desiredLayer ?? DrainageTypes.defaultDesiredLayer,
        useH3 = useH3 ?? true,
        compareAllMethods = compareAllMethods ?? false;
  
  /// Создание настроек по умолчанию
  factory DrainageSettings.defaults() {
    return DrainageSettings();
  }
  
  /// Создание из JSON
  factory DrainageSettings.fromJson(Map<String, dynamic> json) {
    Map<String, List<int>> toleranceMap = {};
    
    if (json.containsKey('tolerance')) {
      final toleranceJson = json['tolerance'] as Map<String, dynamic>;
      toleranceJson.forEach((key, value) {
        if (value is List && value.length == 2) {
          toleranceMap[key] = [
            (value[0] as num).toInt(),
            (value[1] as num).toInt(),
          ];
        }
      });
    }
    
    return DrainageSettings(
      tolerance: toleranceMap.isNotEmpty ? toleranceMap : null,
      kMin: json['k_min'] != null ? (json['k_min'] as num).toDouble() : null,
      delta: json['delta'] != null ? (json['delta'] as num).toInt() : null,
      desiredLayer: json['desired_layer'] != null 
          ? (json['desired_layer'] as num).toDouble() 
          : null,
      useH3: json['use_h3'] as bool?,
      compareAllMethods: json['compare_all_methods'] as bool?,
    );
  }
  
  /// Преобразование в JSON
  Map<String, dynamic> toJson() => {
    'tolerance': tolerance,
    'k_min': kMin,
    'delta': delta,
    'desired_layer': desiredLayer,
    'use_h3': useH3,
    'compare_all_methods': compareAllMethods,
  };
  
  /// Копирование с изменениями
  DrainageSettings copyWith({
    Map<String, List<int>>? tolerance,
    double? kMin,
    int? delta,
    double? desiredLayer,
    bool? useH3,
    bool? compareAllMethods,
  }) {
    return DrainageSettings(
      tolerance: tolerance ?? Map.from(this.tolerance),
      kMin: kMin ?? this.kMin,
      delta: delta ?? this.delta,
      desiredLayer: desiredLayer ?? this.desiredLayer,
      useH3: useH3 ?? this.useH3,
      compareAllMethods: compareAllMethods ?? this.compareAllMethods,
    );
  }
  
  /// Сброс к значениям по умолчанию
  void reset() {
    tolerance = Map.from(DrainageTypes.tolerance);
    kMin = DrainageTypes.kMin;
    delta = DrainageTypes.delta;
    desiredLayer = DrainageTypes.defaultDesiredLayer;
    useH3 = true;
    compareAllMethods = false;
  }
  
  /// Валидация настроек
  String? validate() {
    // Проверка kMin
    if (kMin < 0 || kMin > 10) {
      return 'kMin должен быть в диапазоне [0, 10]';
    }
    
    // Проверка delta
    if (delta < 1 || delta > 20) {
      return 'delta должен быть в диапазоне [1, 20]';
    }
    
    // Проверка desiredLayer
    if (desiredLayer < 20 || desiredLayer > 100) {
      return 'desiredLayer должен быть в диапазоне [20, 100]';
    }
    
    // Проверка допусков
    for (var entry in tolerance.entries) {
      if (entry.value.length != 2) {
        return 'Допуск для ${entry.key} имеет неверную длину';
      }
      if (entry.value[0] > entry.value[1]) {
        return 'Минимум больше максимума для ${entry.key}';
      }
    }
    
    return null;
  }
}
