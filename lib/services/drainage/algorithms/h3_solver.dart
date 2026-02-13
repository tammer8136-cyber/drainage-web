/// Модуль drainage_core - Алгоритм H3 (прямой уклон)
/// Часть системы расчёта дренажного профиля

import '../models/settings.dart';
import 'solver_base.dart';

/// Решатель H3 - монотонный профиль без водораздела
class H3Solver {
  /// Проверяет, можно ли применить H3 (прямой уклон)
  static bool canApplyH3({
    required List<double> F,
    required List<String> T,
    required List<double> L,
    required DrainageSettings settings,
  }) {
    // Условие 1: PR только на концах
    for (int i = 1; i < T.length - 1; i++) {
      if (T[i] == 'PR') {
        return false;
      }
    }
    
    // Условие 2: Достаточный средний уклон
    final double totalLength = L.reduce((a, b) => a + b);
    final double avgSlope = (F.first - F.last).abs() / totalLength;
    
    if (avgSlope < settings.kMin) {
      return false;
    }
    
    return true;
  }
  
  /// Решает задачу методом H3 (жадный алгоритм для прямого уклона)
  static List<Solution> solveH3({
    required List<double> F,
    required List<String> T,
    required List<double> L,
    required List<List<double>> pSet,
    required DrainageSettings settings,
    bool debug = false,
  }) {
    final int N = F.length;
    
    // Создаём копию T и заменяем V на O
    final List<String> T_modified = List.from(T);
    for (int i = 0; i < T_modified.length; i++) {
      if (T_modified[i] == 'V') {
        T_modified[i] = 'O';
      }
    }
    
    final List<Solution> solutions = [];
    
    // Пробуем оба направления
    for (final direction in [-1, 1]) {  // -1 = вниз, 1 = вверх
      for (final p0 in pSet[0]) {
        final List<double> P = List.filled(N, 0);
        P[0] = p0;
        
        bool valid = true;
        
        // Жадно выбираем остальные точки
        for (int i = 1; i < N; i++) {
          double? bestP;
          double bestLocalScore = double.infinity;
          
          for (final p in pSet[i]) {
            // Проверяем уклон с предыдущей точкой
            final k = (P[i-1] - p).abs() / L[i-1];
            if (k < settings.kMin) continue;
            
            // Проверяем направление (без контруклонов)
            if (direction == -1 && P[i-1] < p) continue;  // Должно идти вниз
            if (direction == 1 && P[i-1] > p) continue;   // Должно идти вверх
            
            // Вычисляем локальный score (близость к desired layer)
            final s = F[i] - p;
            final localScore = (s - settings.desiredLayer).abs();
            
            if (localScore < bestLocalScore) {
              bestLocalScore = localScore;
              bestP = p;
            }
          }
          
          if (bestP == null) {
            valid = false;
            break;
          }
          
          P[i] = bestP;
        }
        
        if (!valid) continue;
        
        // Добавляем валидное решение
        solutions.add(Solution(
          P: P,
          vIndex: -1,  // Нет водораздела в H3
          score: 0,
          F: F,
          T: T_modified,
          L: L,
        ));
      }
    }
    
    if (debug) {
      print('[H3] Найдено решений: ${solutions.length}');
    }
    
    return solutions;
  }
}
