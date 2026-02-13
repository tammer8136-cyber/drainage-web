/// Модуль drainage_core - Оптимизация решений
/// Часть системы расчёта дренажного профиля

import '../algorithms/solver_base.dart';

/// Класс для оптимизации найденных решений
class DrainageOptimizer {
  /// Выбор лучшего решения из найденных
  /// Использует интегральный метод для расчёта среднего слоя
  static Solution optimizeSolution({
    required List<Solution> solutions,
    required List<double> F,
    required List<String> T,
    required List<double> L,
    required double desiredLayer,
  }) {
    Solution? bestSolution;
    double bestScore = double.infinity;
    
    for (Solution sol in solutions) {
      final List<double> FForCalc = sol.F ?? F;
      final List<String> TForCalc = sol.T ?? T;
      final List<double> LForCalc = sol.L ?? L;
      final int N = sol.P.length;
      
      // ШАГ 1: Вычисляем эффективные слои для ВСЕХ точек (включая PR!)
      final List<double> sEff = [];
      
      for (int i = 0; i < N; i++) {
        final double sRaw = FForCalc[i] - sol.P[i];
        double sIEff;
        
        if (TForCalc[i] == 'PR') {
          // PR участвует с S_eff = desiredLayer - 10
          sIEff = desiredLayer - 10;
          
        } else if (TForCalc[i] == 'P') {
          // P гибкий
          sIEff = desiredLayer;
          
        } else if (TForCalc[i] == 'K') {
          // K использует -10
          if (sRaw > 70) {
            sIEff = desiredLayer;
          } else if (sRaw == 60) {
            sIEff = desiredLayer - 10;
          } else if (sRaw > 60 && sRaw <= 70) {
            sIEff = sRaw - 10;
          } else {
            sIEff = sRaw;
          }
          
        } else {
          // Обычные точки (O, V, DK)
          sIEff = sRaw;
        }
        
        sEff.add(sIEff);
      }
      
      // ШАГ 2: ИНТЕГРАЛЬНОЕ СРЕДНЕЕ (метод трапеций)
      double integral = 0;
      double totalLength = 0;
      
      for (int i = 0; i < N - 1; i++) {
        // Площадь трапеции: (h1 + h2) / 2 * base
        final double trapezoidArea = (sEff[i] + sEff[i + 1]) / 2 * LForCalc[i];
        integral += trapezoidArea;
        totalLength += LForCalc[i];
      }
      
      final double sAvg = totalLength > 0 ? integral / totalLength : 0;
      
      // ШАГ 3: Штрафы за уклоны
      double scoreK = 0;
      for (int i = 0; i < N - 1; i++) {
        final double kI = (sol.P[i] - sol.P[i + 1]).abs() / LForCalc[i];
        scoreK += _penaltyK(kI);
      }
      
      // ШАГ 4: Общий балл
      final double score = (sAvg - desiredLayer).abs() + scoreK;
      
      if (score < bestScore) {
        bestScore = score;
        bestSolution = Solution(
          P: sol.P,
          vIndex: sol.vIndex,
          score: score,
          averageLayer: sAvg,
          F: sol.F,
          T: sol.T,
          L: sol.L,
          metadata: sol.metadata,
        );
      }
    }
    
    return bestSolution!;
  }
  
  /// Штраф за уклон
  static double _penaltyK(double k) {
    final double kAbs = k.abs();
    
    if (kAbs < 3.0) {
      return 1000;
    } else if (kAbs <= 3.75) {
      return 10;
    } else if (kAbs <= 5.0) {
      return 1;
    } else {
      return 0;
    }
  }
}
