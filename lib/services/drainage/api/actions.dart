/// Модуль drainage_core - API функции
/// Часть системы расчёта дренажного профиля
/// 
/// Предоставляет JSON-based API для использования в UI

import 'dart:convert';
import '../models/input.dart';
import '../models/settings.dart';
import '../models/validation.dart';
import '../solver.dart';

// ============================================================================
// ГЛОБАЛЬНЫЕ НАСТРОЙКИ
// ============================================================================

DrainageSettings globalSettings = DrainageSettings.defaults();

// ============================================================================
// JSON API ФУНКЦИИ (используются в UI)
// ============================================================================

/// Расчёт дренажной системы через JSON
Future<String> calculateDrainageAction(
  String pointsJson,
  bool useH2,
  double desiredLayer, {
  double? kMin,
  int? delta,
  bool? useH3,
  bool? compareAllMethods,
  Map<String, List<int>>? tolerance,
}) async {
  try {
    // Парсим входные данные
    final List<dynamic> pointsList = jsonDecode(pointsJson) as List<dynamic>;
    
    if (pointsList.isEmpty) {
      return jsonEncode({
        'status': 'НЕРЕШАЕМО',
        'error': 'Список точек пустой',
        'computation_time': 0.0,
      });
    }
    
    // Извлекаем F, T, L
    final List<double> F = [];
    final List<String> T = [];
    final List<double> L = [];
    
    for (int i = 0; i < pointsList.length; i++) {
      final point = pointsList[i] as Map<String, dynamic>;
      
      // F - обязательное
      if (!point.containsKey('f')) {
        return jsonEncode({
          'status': 'НЕРЕШАЕМО',
          'error': 'Точка $i: отсутствует поле "f"',
          'computation_time': 0.0,
        });
      }
      F.add((point['f'] as num).toDouble());
      
      // Type - обязательное
      if (!point.containsKey('type')) {
        return jsonEncode({
          'status': 'НЕРЕШАЕМО',
          'error': 'Точка $i: отсутствует поле "type"',
          'computation_time': 0.0,
        });
      }
      T.add(point['type'] as String);
      
      // Length - для всех кроме последней точки
      if (i < pointsList.length - 1) {
        if (!point.containsKey('length')) {
          return jsonEncode({
            'status': 'НЕРЕШАЕМО',
            'error': 'Точка $i: отсутствует поле "length"',
            'computation_time': 0.0,
          });
        }
        L.add((point['length'] as num).toDouble());
      }
    }
    
    // Создаём настройки для расчёта
    final settings = DrainageSettings(
      kMin: kMin,
      delta: delta,
      desiredLayer: desiredLayer,
      tolerance: tolerance,
      useH3: useH3,
      compareAllMethods: compareAllMethods,
    );
    
    // Вызываем основной алгоритм
    final result = await DrainageSolver.solve(
      F: F,
      T: T,
      L: L,
      refineWatershed: useH2,
      debug: false,
      desiredLayer: desiredLayer,
      settings: settings,
    );
    
    // Возвращаем результат в JSON
    return jsonEncode(result.toJson());
    
  } catch (e) {
    return jsonEncode({
      'status': 'НЕРЕШАЕМО',
      'error': 'Ошибка расчёта: $e',
      'computation_time': 0.0,
    });
  }
}

/// Валидация входных данных через JSON
String validateInputAction(String pointsJson) {
  try {
    final List<dynamic> pointsList = jsonDecode(pointsJson) as List<dynamic>;
    
    if (pointsList.isEmpty) {
      return jsonEncode({
        'valid': false,
        'message': 'Список точек пустой'
      });
    }
    
    if (pointsList.length < 3) {
      return jsonEncode({
        'valid': false,
        'message': 'Минимум 3 точки требуется'
      });
    }
    
    // Извлекаем данные
    final List<double> F = [];
    final List<String> T = [];
    final List<double> L = [];
    
    for (int i = 0; i < pointsList.length; i++) {
      final point = pointsList[i] as Map<String, dynamic>;
      
      if (!point.containsKey('f') || !point.containsKey('type')) {
        return jsonEncode({
          'valid': false,
          'message': 'Точка $i: отсутствуют обязательные поля'
        });
      }
      
      F.add((point['f'] as num).toDouble());
      T.add(point['type'] as String);
      
      if (i < pointsList.length - 1) {
        if (!point.containsKey('length')) {
          return jsonEncode({
            'valid': false,
            'message': 'Точка $i: отсутствует поле length'
          });
        }
        L.add((point['length'] as num).toDouble());
      }
    }
    
    // Используем встроенную валидацию
    final input = DrainageInput(F: F, T: T, L: L);
    final validation = DrainageValidation.validate(input);
    
    return jsonEncode({
      'valid': validation.isValid,
      'message': validation.message,
    });
    
  } catch (e) {
    return jsonEncode({
      'valid': false,
      'message': 'Ошибка валидации: $e'
    });
  }
}

/// Обновить параметры расчёта
void updateSettingsAction(
  double kMin,
  int delta,
  double desiredLayerValue,
) {
  globalSettings = DrainageSettings(
    tolerance: Map.from(globalSettings.tolerance),
    kMin: kMin,
    delta: delta,
    desiredLayer: desiredLayerValue,
  );
}

/// Вспомогательная функция: получить текущие настройки
String getSettingsAction() {
  return jsonEncode({
    'k_min': globalSettings.kMin,
    'delta': globalSettings.delta,
    'desired_layer': globalSettings.desiredLayer,
  });
}

/// Вспомогательная функция: получить допуски
String getTolerancesAction() {
  return jsonEncode(globalSettings.tolerance);
}

/// Вспомогательная функция: сбросить настройки по умолчанию
void resetSettingsAction() {
  globalSettings = DrainageSettings.defaults();
}
