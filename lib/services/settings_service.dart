import 'package:shared_preferences/shared_preferences.dart';
import 'drainage_core.dart';

/// Сервис для сохранения и загрузки глобальных настроек приложения
class SettingsService {
  static const String _keyKMin = 'settings_k_min';
  static const String _keyDelta = 'settings_delta';
  static const String _keyDesiredLayer = 'settings_desired_layer';
  static const String _keyUseH2 = 'settings_use_h2';
  static const String _keyUseH3 = 'settings_use_h3';
  static const String _keyCompareAllMethods = 'settings_compare_all_methods';
  static const String _keyTolerancePrefix = 'settings_tolerance_';
  
  /// Сохранить настройки
  static Future<void> saveSettings({
    required double kMin,
    required int delta,
    required double desiredLayer,
    required bool useH2,
    required bool useH3,
    required bool compareAllMethods,
    required Map<String, List<int>> tolerance,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setDouble(_keyKMin, kMin);
    await prefs.setInt(_keyDelta, delta);
    await prefs.setDouble(_keyDesiredLayer, desiredLayer);
    await prefs.setBool(_keyUseH2, useH2);
    await prefs.setBool(_keyUseH3, useH3);
    await prefs.setBool(_keyCompareAllMethods, compareAllMethods);
    
    // Сохраняем допуски
    for (var entry in tolerance.entries) {
      await prefs.setString(
        '$_keyTolerancePrefix${entry.key}',
        '${entry.value[0]},${entry.value[1]}',
      );
    }
  }
  
  /// Загрузить настройки (или дефолтные)
  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Загружаем допуски
    final tolerance = <String, List<int>>{};
    for (var type in DrainageTypes.tolerance.keys) {
      final key = '$_keyTolerancePrefix$type';
      if (prefs.containsKey(key)) {
        final parts = prefs.getString(key)!.split(',');
        tolerance[type] = [int.parse(parts[0]), int.parse(parts[1])];
      } else {
        tolerance[type] = List.from(DrainageTypes.tolerance[type]!);
      }
    }
    
    return {
      'kMin': prefs.getDouble(_keyKMin) ?? DrainageTypes.kMin,
      'delta': prefs.getInt(_keyDelta) ?? DrainageTypes.delta,
      'desiredLayer': prefs.getDouble(_keyDesiredLayer) ?? DrainageTypes.defaultDesiredLayer,
      'useH2': prefs.getBool(_keyUseH2) ?? true,
      'useH3': prefs.getBool(_keyUseH3) ?? true,
      'compareAllMethods': prefs.getBool(_keyCompareAllMethods) ?? false,
      'tolerance': tolerance,
    };
  }
  
  /// Сбросить настройки к дефолтным
  static Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_keyKMin);
    await prefs.remove(_keyDelta);
    await prefs.remove(_keyDesiredLayer);
    await prefs.remove(_keyUseH2);
    await prefs.remove(_keyUseH3);
    await prefs.remove(_keyCompareAllMethods);
    
    // Удаляем все допуски
    for (var type in DrainageTypes.tolerance.keys) {
      await prefs.remove('$_keyTolerancePrefix$type');
    }
  }
}
