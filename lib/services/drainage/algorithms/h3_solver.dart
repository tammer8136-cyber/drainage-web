/// Модуль drainage_core - Алгоритм H3 (прямой уклон)
/// Часть системы расчёта дренажного профиля

import '../models/types.dart';
import '../models/settings.dart';
import 'solver_base.dart';

/// Решатель H3 - монотонный профиль без водораздела.
/// Использует полный перебор BnB (не жадный алгоритм).
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
      if (T[i] == 'PR') return false;
    }

    // Условие 2: Достаточный средний уклон
    final double totalLength = L.reduce((a, b) => a + b);
    final double avgSlope = (F.first - F.last).abs() / totalLength;
    return avgSlope >= settings.kMin;
  }

  /// Решает задачу методом H3 — полный перебор BnB.
  /// Возвращает одно лучшее решение (или пустой список).
  static List<Solution> solveH3({
    required List<double> F,
    required List<String> T,
    required List<double> L,
    required List<List<double>> pSet,
    required DrainageSettings settings,
    bool debug = false,
  }) {
    final int N = F.length;

    // Заменяем V/VK на O — H3 не работает с водоразделом
    final List<String> tMod = T.map((t) => (t == 'V' || t == 'VK') ? 'O' : t).toList();

    // Rebuild pSet под tMod (V→O меняет допуски)
    final List<List<double>> pSetMod = generatePSet(F, tMod, settings);

    Solution? best;
    double bestScore = double.infinity;

    final List<double> buffer = List.filled(N, 0.0);

    // BnB перебор: два прохода — вниз и вверх
    for (final int dir in [-1, 1]) {
      void backtrack(int idx) {
        if (idx == N) {
          // Оцениваем решение
          final double score = _scoreH3(buffer, F, tMod, L, settings.desiredLayer);
          if (score < bestScore) {
            bestScore = score;
            best = Solution(
              P: List<double>.from(buffer),
              vIndex: -1,
              score: score,
              F: F,
              T: tMod,
              L: L,
            );
          }
          return;
        }

        for (final double p in pSetMod[idx]) {
          // Слой уже гарантирован pSet — проверяем только уклон
          if (idx > 0) {
            final double k = (buffer[idx - 1] - p).abs() / L[idx - 1];
            if (k < settings.kMin) continue;

            // Монотонность направления
            if (dir == -1 && p > buffer[idx - 1]) continue; // вниз
            if (dir == 1  && p < buffer[idx - 1]) continue; // вверх
          }

          buffer[idx] = p;
          backtrack(idx + 1);
        }
      }

      backtrack(0);
    }

    if (debug) {
      print('[H3] best score: $bestScore, found: ${best != null}');
    }

    return best != null ? [best!] : [];
  }

  /// Скор: интегральное среднее отклонение слоёв от desiredLayer.
  static double _scoreH3(
    List<double> P,
    List<double> F,
    List<String> T,
    List<double> L,
    double desiredLayer,
  ) {
    double integral = 0;
    double totalLen = 0;
    for (int i = 0; i < L.length; i++) {
      final double s1 = (T[i] == 'PR') ? desiredLayer : (F[i] - P[i]);
      final double s2 = (T[i + 1] == 'PR') ? desiredLayer : (F[i + 1] - P[i + 1]);
      integral += ((s1 - desiredLayer).abs() + (s2 - desiredLayer).abs()) / 2 * L[i];
      totalLen += L[i];
    }
    return totalLen > 0 ? integral / totalLen : double.infinity;
  }
}
