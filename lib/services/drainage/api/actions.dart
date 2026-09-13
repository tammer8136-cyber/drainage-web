/// Модуль drainage_core - API функции
/// Часть системы расчёта дренажного профиля

import 'dart:convert';
import '../models/settings.dart';
import '../solver.dart';

// ============================================================================
// API ФУНКЦИЯ ДЛЯ РАСЧЁТА
// ============================================================================
//
// Изначально этот файл был слоем API-функций под FlutterFlow custom actions
// (передача через JSON-строки вместо прямых Dart-вызовов). После переезда с
// FlutterFlow на обычный Flutter только calculateDrainageAction осталась
// реально используемой — остальные функции (validateInputAction,
// updateSettingsAction, getSettingsAction, getTolerancesAction,
// resetSettingsAction) и глобальная переменная globalSettings нигде не
// вызывались, удалены при уборке.

/// Action #1: Расчёт дренажной системы
Future<String> calculateDrainageAction(
  String pointsJson,
  bool useH2,
  double desiredLayer, {
  double? kMin,
  int? delta,
  bool? useH3,
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
