/// Модуль drainage_core - Алгоритм H2 (плавающий водораздел)
/// Часть системы расчёта дренажного профиля

import '../models/types.dart';
import '../models/result.dart';
import '../models/settings.dart';
import 'solver_base.dart';
import '../optimization/optimizer.dart';

/// Решатель H2 - поиск оптимального водораздела через виртуальные точки
class H2Solver {
  /// Решение с плавающим водоразделом.
  /// Возвращает ОДНО лучшее решение (или пустой список если не найдено).
  /// Inline best tracking — не накапливает все решения в памяти.
  static List<Solution> solveH2({
    required List<double> F,
    required List<String> T,
    required List<double> L,
    required List<List<double>> pSet,
    required DrainageSettings settings,
    bool debug = false,
  }) {
    if (debug) {
      print('\n${'=' * 80}');
      print('[H2] Плавающий водораздел с виртуальными точками');
      print('=' * 80);
    }

    // Inline best — один глобальный best вместо накопления всех решений
    Solution? bestSolution;
    double bestScore = double.infinity;

    // Генерация виртуальных позиций водораздела (шаг 1м)
    double cumulativeDist = 0;

    for (int segIdx = 0; segIdx < L.length; segIdx++) {
      final double segLen = L[segIdx];

      for (int offset = 1; offset < segLen.floor(); offset++) {
        // Интерполяция F для виртуальной точки
        final double fStart = F[segIdx];
        final double fEnd = F[segIdx + 1];
        final double fVirtual = fStart + (fEnd - fStart) * (offset / segLen);

        // Расширенные массивы
        final List<double> fExt = [
          ...F.sublist(0, segIdx + 1),
          fVirtual,
          ...F.sublist(segIdx + 1),
        ];
        final List<String> tExt = [
          ...T.sublist(0, segIdx + 1),
          'V',
          ...T.sublist(segIdx + 1),
        ];
        final List<double> lExt = [
          ...L.sublist(0, segIdx),
          offset.toDouble(),
          segLen - offset,
          ...L.sublist(segIdx + 1),
        ];

        final int nExt = fExt.length;
        final int vIdx = segIdx + 1;

        final List<List<double>> pSetExt = generatePSet(fExt, tExt, settings);
        // Допуск водораздела берём ИЗ НАСТРОЕК, а не из встроенной
        // константы: раньше здесь стоял DrainageTypes.tolerance['V'], и
        // слой на водоразделе упирался в дефолт независимо от того, что
        // выставлено в настройках проекта.
        final tolV = settings.tolerance['V'] ?? DrainageTypes.tolerance['V']!;

        for (final double pV in pSetExt[vIdx]) {
          final double sV = fExt[vIdx] - pV;
          if (sV < tolV[0] || sV > tolV[1]) continue;

          // Inline обработка левых и правых сегментов через callback
          if (vIdx > 0) {
            generateSegmentBnb(
              F: fExt, T: tExt, L: lExt, pSet: pSetExt,
              startIdx: 0, endIdx: vIdx - 1,
              direction: 'left', settings: settings,
              onSolution: (leftSeg) {
                final double kToV = (leftSeg.last - pV).abs() / lExt[vIdx - 1];
                if (kToV < settings.kMin) return;

                if (vIdx < nExt - 1) {
                  generateSegmentBnb(
                    F: fExt, T: tExt, L: lExt, pSet: pSetExt,
                    startIdx: vIdx + 1, endIdx: nExt - 1,
                    direction: 'right', settings: settings,
                    onSolution: (rightSeg) {
                      final double kFromV = (pV - rightSeg.first).abs() / lExt[vIdx];
                      if (kFromV < settings.kMin) return;

                      final List<double> full = [...leftSeg, pV, ...rightSeg];

                      if (!isSolutionValid(
                        P: full, vIndex: vIdx,
                        F: fExt, T: tExt, L: lExt,
                        settings: settings,
                      )) return;

                      // Настоящий балл — тот же, что у оптимизатора
                      final double score = DrainageOptimizer.evaluate(P: full, F: fExt, T: tExt, L: lExt, desiredLayer: settings.desiredLayer)[0];
                      if (score < bestScore) {
                        bestScore = score;
                        bestSolution = Solution(
                          P: full,
                          vIndex: vIdx,
                          score: score,
                          F: fExt, T: tExt, L: lExt,
                          metadata: DrainageMetadata(
                            virtual: true,
                            segment: segIdx,
                            offset: offset,
                          ),
                        );
                      }
                    },
                  );
                } else {
                  final List<double> full = [...leftSeg, pV];
                  if (!isSolutionValid(
                    P: full, vIndex: vIdx,
                    F: fExt, T: tExt, L: lExt,
                    settings: settings,
                  )) return;
                  final double score = DrainageOptimizer.evaluate(P: full, F: fExt, T: tExt, L: lExt, desiredLayer: settings.desiredLayer)[0];
                  if (score < bestScore) {
                    bestScore = score;
                    bestSolution = Solution(
                      P: full, vIndex: vIdx, score: score,
                      F: fExt, T: tExt, L: lExt,
                      metadata: DrainageMetadata(virtual: true, segment: segIdx, offset: offset),
                    );
                  }
                }
              },
            );
          } else if (vIdx < nExt - 1) {
            generateSegmentBnb(
              F: fExt, T: tExt, L: lExt, pSet: pSetExt,
              startIdx: vIdx + 1, endIdx: nExt - 1,
              direction: 'right', settings: settings,
              onSolution: (rightSeg) {
                final double kFromV = (pV - rightSeg.first).abs() / lExt[vIdx];
                if (kFromV < settings.kMin) return;

                final List<double> full = [pV, ...rightSeg];
                if (!isSolutionValid(
                  P: full, vIndex: vIdx,
                  F: fExt, T: tExt, L: lExt,
                  settings: settings,
                )) return;
                final double score = DrainageOptimizer.evaluate(P: full, F: fExt, T: tExt, L: lExt, desiredLayer: settings.desiredLayer)[0];
                if (score < bestScore) {
                  bestScore = score;
                  bestSolution = Solution(
                    P: full, vIndex: vIdx, score: score,
                    F: fExt, T: tExt, L: lExt,
                    metadata: DrainageMetadata(virtual: true, segment: segIdx, offset: offset),
                  );
                }
              },
            );
          }
        }
      }

      cumulativeDist += segLen;
    }

    if (debug) {
      print('[H2] best score: $bestScore');
    }

    return bestSolution != null ? [bestSolution!] : [];
  }

}
