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
  /// Полный балл одного решения + средний слой (для отображения).
  ///
  /// ЕДИНСТВЕННОЕ место, где считается балл. Раньше H2 и H3 выбирали
  /// своего победителя собственными упрощёнными формулами (без штрафа за
  /// уклон, без веса по длине, без подстановок PR/P/карта) и отдавали
  /// оптимизатору список из одного элемента — то есть настоящий балл на
  /// выбор в этих солверах не влиял вообще. Теперь все три солвера и
  /// оптимизатор считают одной и той же функцией.
  ///
  /// Возвращает [score, averageLayer].
  static List<double> evaluate({
    required List<double> P,
    required List<double> F,
    required List<String> T,
    required List<double> L,
    required double desiredLayer,
  }) {
    final int N = P.length;

    // ШАГ 1: Эффективные слои для ВСЕХ точек (включая PR!)
    final List<double> sEff = [];
    for (int i = 0; i < N; i++) {
      final double sRaw = F[i] - P[i];
      double sIEff;

      if (T[i] == 'PR') {
        // PR — жёсткая спайка, слой там не про толщину покрытия:
        // подставляем нейтральное значение, чтобы точка не искажала
        // среднее по регулируемым точкам.
        sIEff = desiredLayer - 10;
      } else if (T[i] == 'P') {
        // P — подстройка под верх бордюра, слой там тоже не имеет смысла
        // как отдельная величина.
        sIEff = desiredLayer;
      } else if (T[i] == 'K' || T[i] == 'VK' || T[i] == 'DKK') {
        // Карта (срез 2 слоёв асфальта): нижний слой — минимум
        // DrainageTypes.kartaLowerLayerMin, верхний — до desiredLayer.
        if (sRaw >= desiredLayer + DrainageTypes.kartaLowerLayerMin) {
          sIEff = desiredLayer;
        } else {
          sIEff = sRaw - DrainageTypes.kartaLowerLayerMin;
        }
      } else {
        // Обычные точки (O, V, DK) — слой выбирается свободно.
        sIEff = sRaw;
      }
      sEff.add(sIEff);
    }

    // ШАГ 2: Средний слой участка — статистика для отображения
    double integralAvg = 0;
    double totalLength = 0;
    for (int i = 0; i < N - 1; i++) {
      integralAvg += (sEff[i] + sEff[i + 1]) / 2 * L[i];
      totalLength += L[i];
    }
    final double sAvg = totalLength > 0 ? integralAvg / totalLength : 0;

    // ШАГ 3: Штраф за слой — по каждой точке, усреднение по длине
    double integralPenalty = 0;
    for (int i = 0; i < N - 1; i++) {
      final double pI = _penaltyLayer(sEff[i], desiredLayer);
      final double pI1 = _penaltyLayer(sEff[i + 1], desiredLayer);
      integralPenalty += (pI + pI1) / 2 * L[i];
    }
    final double scoreLayer = totalLength > 0 ? integralPenalty / totalLength : 0;

    // ШАГ 4: Штраф за уклон
    double scoreK = 0;
    for (int i = 0; i < N - 1; i++) {
      final double kI = (P[i] - P[i + 1]).abs() / L[i];
      scoreK += _penaltyK(kI);
    }

    // ШАГ 5: Штраф за неравномерность слоя между свободными точками
    double scoreLayerRate = 0;
    for (int i = 0; i < N - 1; i++) {
      if (DrainageTypes.freeLayerTypes.contains(T[i]) &&
          DrainageTypes.freeLayerTypes.contains(T[i + 1])) {
        final double rate = (sEff[i + 1] - sEff[i]).abs() / L[i];
        scoreLayerRate += _penaltyLayerRate(rate);
      }
    }

    return [scoreLayer + scoreK + scoreLayerRate, sAvg];
  }

  /// Выбор лучшего решения из найденных — по evaluate().
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
      final r = evaluate(
        P: sol.P,
        F: sol.F ?? F,
        T: sol.T ?? T,
        L: sol.L ?? L,
        desiredLayer: desiredLayer,
      );
      final double score = r[0];
      if (score < bestScore) {
        bestScore = score;
        bestSolution = Solution(
          P: sol.P,
          vIndex: sol.vIndex,
          score: score,
          averageLayer: r[1],
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
  
  /// Штраф за уклон.
  ///
  /// Пороги АБСОЛЮТНЫЕ и от kMin не зависят — это нормативный смысл, а не
  /// производная от настройки: от 3.0 вода начинает уходить, от 3.75
  /// начинается хороший уклон, от 5.0 — очень хороший.
  ///
  /// Границы включают «хорошую» сторону: ровно 5.0 уже бесплатно. Раньше
  /// было `<= 5.0 → 1`, из-за чего уклон 5.0 стоил балл, а 5.01 — ноль,
  /// то есть более крутой обгонял по баллам совершенно нормальный. На
  /// практике это перевешивало реальный выигрыш по слою.
  static double _penaltyK(double k) {
    final double kAbs = k.abs();

    if (kAbs < 3.0) {
      return 1000;
    } else if (kAbs < 3.75) {
      return 10;
    } else if (kAbs < 5.0) {
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
