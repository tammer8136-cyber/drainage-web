/// Перепрофилирование края под фрезу — точка входа для расчёта.
///
/// Как и в дренажном расчёте, тяжёлый перебор уходит в отдельный isolate
/// через compute() — интерфейс остаётся отзывчивым. compute() умеет
/// передавать только простые сериализуемые данные, поэтому вход/выход —
/// JSON-строки.

import 'dart:convert';
import '../models/milling_models.dart';
import '../milling_solver.dart';

/// Расчёт фрезы. [params] ожидает:
///   'stationsJson' — JSON-массив станций (см. MillingStation.toJson)
///   'settingsJson' — JSON настроек (см. MillingSettings.toJson)
/// Возвращает JSON результата (см. MillingResult.toJson).
Future<String> calculateMillingIsolate(Map<String, dynamic> params) async {
  try {
    final stationsRaw = jsonDecode(params['stationsJson'] as String) as List;
    final stations = stationsRaw
        .map((e) => MillingStation.fromJson(e as Map<String, dynamic>))
        .toList();

    final settings = params['settingsJson'] != null
        ? MillingSettings.fromJson(
            jsonDecode(params['settingsJson'] as String) as Map<String, dynamic>)
        : MillingSettings.defaults();

    final result = MillingSolver.solve(stations: stations, settings: settings);
    return jsonEncode(result.toJson());
  } catch (e) {
    return jsonEncode(
      MillingResult.error('Ошибка расчёта: $e', 0.0, 50.0).toJson(),
    );
  }
}
