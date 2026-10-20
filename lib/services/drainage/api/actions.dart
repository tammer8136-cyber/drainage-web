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

/// Точка входа для compute() — перенос тяжёлого расчёта в отдельный isolate.
///
/// Раньше `_calculate()` вызывал calculateDrainageAction() напрямую: хотя
/// функция помечена async, внутри неё нет реального await на асинхронную
/// операцию — весь branch-and-bound перебор выполняется синхронно в
/// основном UI-потоке. При 10+ точках расчёт занимает секунды, всё это
/// время интерфейс не может отрисовываться и реагировать — Android
/// показывает «не отвечает», и результат (который к этому моменту уже
/// посчитан и сохранён) виден только после перезахода.
///
/// compute() запускает переданную функцию в отдельном isolate — сюда можно
/// передать только простые сериализуемые данные (что и так уже было нужно
/// для JSON-based интерфейса calculateDrainageAction), никаких доработок
/// сигнатуры не потребовалось.
Future<String> calculateDrainageIsolate(Map<String, dynamic> params) async {
  return await calculateDrainageAction(
    params['pointsJson'] as String,
    params['useH2'] as bool,
    params['desiredLayer'] as double,
    kMin: params['kMin'] as double?,
    delta: params['delta'] as int?,
    useH3: params['useH3'] as bool?,
    compareAllMethods: params['compareAllMethods'] as bool?,
    tolerance: params['tolerance'] != null
        ? Map<String, List<int>>.from(
            (params['tolerance'] as Map).map(
              (key, value) => MapEntry(
                key as String,
                List<int>.from(value as List),
              ),
            ),
          )
        : null,
  );
}
