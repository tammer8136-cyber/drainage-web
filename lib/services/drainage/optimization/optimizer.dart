/// Модуль drainage_core - Оптимизация решений
/// Часть системы расчёта дренажного профиля

import '../algorithms/solver_base.dart';
import '../models/types.dart';

/// Класс для оптимизации найденных решений
class DrainageOptimizer {
  /// Выбор лучшего решения из найденных
  /// score = scoreLayer (штраф за слой, по каждой точке) + scoreK (штраф за
  /// уклон) + scoreLayerRate (штраф за неравномерность слоя между соседними
  /// свободными точками)
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
          // PR — жёсткая спайка, слой там не про толщину покрытия:
          // подставляем нейтральное значение, чтобы точка не искажала
          // среднее по регулируемым точкам.
          sIEff = desiredLayer - 10;
          
        } else if (TForCalc[i] == 'P') {
          // P — подстройка под верх бордюра, слой там тоже не имеет смысла
          // как отдельная величина.
          sIEff = desiredLayer;
          
        } else if (TForCalc[i] == 'K' || TForCalc[i] == 'VK' || TForCalc[i] == 'DKK') {
          // Карта (срез 2 слоёв асфальта): нижний слой — минимум
          // DrainageTypes.kartaLowerLayerMin (физически необходимая
          // толщина), верхний — до desiredLayer. Если карта тоньше
          // desiredLayer + kartaLowerLayerMin, весь слой сверх минимума
          // нижнего идёт в верхний; если толще — верхний фиксируется на
          // desiredLayer, а весь избыток уходит в нижний.
          if (sRaw >= desiredLayer + DrainageTypes.kartaLowerLayerMin) {
            sIEff = desiredLayer;
          } else {
            sIEff = sRaw - DrainageTypes.kartaLowerLayerMin;
          }
          
        } else {
          // Обычные точки (O, V, DK) — слой выбирается алгоритмом свободно.
          sIEff = sRaw;
        }
        
        sEff.add(sIEff);
      }
      
      // ШАГ 2: Средний слой участка — статистика для отображения
      // пользователю (не участвует в score с этой версии формулы).
      double integralAvg = 0;
      double totalLength = 0;
      
      for (int i = 0; i < N - 1; i++) {
        final double trapezoidArea = (sEff[i] + sEff[i + 1]) / 2 * LForCalc[i];
        integralAvg += trapezoidArea;
        totalLength += LForCalc[i];
      }
      
      final double sAvg = totalLength > 0 ? integralAvg / totalLength : 0;
      
      // ШАГ 3: Штраф за слой — по каждой точке отдельно, потом штрафы
      // усредняются по длине (тем же методом трапеций). В отличие от
      // штрафа по среднему участка, это не даёт рваному профилю (например
      // 35мм на одном конце, 70мм на другом) "прятаться" за хорошим
      // средним — обе точки оцениваются сами по себе.
      double integralPenalty = 0;
      for (int i = 0; i < N - 1; i++) {
        final double pI = _penaltyLayer(sEff[i], desiredLayer);
        final double pI1 = _penaltyLayer(sEff[i + 1], desiredLayer);
        integralPenalty += (pI + pI1) / 2 * LForCalc[i];
      }
      final double scoreLayer = totalLength > 0 ? integralPenalty / totalLength : 0;
      
      // ШАГ 4: Штраф за уклон
      double scoreK = 0;
      for (int i = 0; i < N - 1; i++) {
        final double kI = (sol.P[i] - sol.P[i + 1]).abs() / LForCalc[i];
        scoreK += _penaltyK(kI);
      }
      
      // ШАГ 5: Штраф за неравномерность слоя между соседними точками —
      // только между точками, где слой выбирается свободно (O/V/DK).
      // Сегменты, касающиеся PR/P/K/VK/DKK (спроектированные переходы, не
      // случайная рваность), из этого штрафа исключены полностью.
      double scoreLayerRate = 0;
      for (int i = 0; i < N - 1; i++) {
        if (DrainageTypes.freeLayerTypes.contains(TForCalc[i]) &&
            DrainageTypes.freeLayerTypes.contains(TForCalc[i + 1])) {
          final double rate = (sEff[i + 1] - sEff[i]).abs() / LForCalc[i];
          scoreLayerRate += _penaltyLayerRate(rate);
        }
      }
      
      // ШАГ 6: Общий балл
      final double score = scoreLayer + scoreK + scoreLayerRate;
      
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
  
  /// Штраф за отклонение слоя от desiredLayer в конкретной точке.
  /// Линейный, в обе стороны, один и тот же вес — при плохом уклоне scoreK
  /// доминирует за счёт масштаба (1000/10/1/0), так что экономия слоя без
  /// хорошего уклона не может перевесить сама по себе.
  static double _penaltyLayer(double sEff, double desiredLayer) {
    const double w = 0.3; // баллов за мм отклонения, в обе стороны
    return w * (sEff - desiredLayer).abs();
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
  
  /// Штраф за скорость изменения слоя между соседними свободными точками
  /// (мм слоя на метр длины). Пороги откалиброваны по реальным принятым
  /// решениям за сезон (524 сегмента O/V/DK↔O/V/DK): медиана 0.77 мм/м,
  /// 90-й перцентиль 3.33 мм/м, 99-й — 10.0 мм/м, максимум — 20.0 мм/м.
  static double _penaltyLayerRate(double rate) {
    final double rateAbs = rate.abs();
    
    if (rateAbs <= 3.3) {
      return 0;
    } else if (rateAbs <= 7.5) {
      return 3;
    } else if (rateAbs <= 10.0) {
      return 8;
    } else {
      return 20;
    }
  }
}
