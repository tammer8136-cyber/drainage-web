/// Модуль drainage_core - Алгоритм H2 (плавающий водораздел)
/// Часть системы расчёта дренажного профиля

import '../models/types.dart';
import '../models/result.dart';
import '../models/settings.dart';
import 'solver_base.dart';

/// Решатель H2 - поиск оптимального водораздела через виртуальные точки
class H2Solver {
  /// Решение с плавающим водоразделом
  static List<Solution> solveH2({
    required List<double> F,
    required List<String> T,
    required List<double> L,
    required List<List<double>> pSet,
    required DrainageSettings settings,
    bool debug = false,
  }) {
    final List<Solution> solutions = [];
    
    if (debug) {
      print('\n${'=' * 80}');
      print('[H2] Плавающий водораздел с виртуальными точками');
      print('=' * 80);
    }
    
    // Генерация виртуальных позиций водораздела (шаг 1м)
    final List<VirtualPosition> virtualPositions = [];
    double cumulativeDist = 0;
    
    for (int segIdx = 0; segIdx < L.length; segIdx++) {
      final double segLen = L[segIdx];
      
      // Виртуальные точки внутри сегмента с шагом 1м
      for (int offset = 1; offset < segLen.floor(); offset++) {
        virtualPositions.add(VirtualPosition(
          segment: segIdx,
          offset: offset,
          cumulative: cumulativeDist + offset,
        ));
      }
      
      cumulativeDist += segLen;
    }
    
    if (debug) {
      print('[H2] Сгенерировано ${virtualPositions.length} виртуальных позиций');
    }
    
    // Перебор виртуальных позиций
    for (VirtualPosition vp in virtualPositions) {
      final int segIdx = vp.segment;
      final int offset = vp.offset;
      
      // Интерполяция F для виртуальной точки
      final double fStart = F[segIdx];
      final double fEnd = F[segIdx + 1];
      final double lSeg = L[segIdx];
      final double fVirtual = fStart + (fEnd - fStart) * (offset / lSeg);
      
      // Построение расширенных массивов
      final List<double> fExtended = [
        ...F.sublist(0, segIdx + 1),
        fVirtual,
        ...F.sublist(segIdx + 1),
      ];
      
      final List<String> tExtended = [
        ...T.sublist(0, segIdx + 1),
        'V',  // Виртуальная точка - это водораздел!
        ...T.sublist(segIdx + 1),
      ];
      
      final List<double> lExtended = [
        ...L.sublist(0, segIdx),
        offset.toDouble(),
        lSeg - offset,
        ...L.sublist(segIdx + 1),
      ];
      
      final int nExt = fExtended.length;
      final int vIdxExt = segIdx + 1;  // Индекс виртуального водораздела
      
      if (debug) {
        print('\n${'=' * 80}');
        print('[H2] 🔍 ВИРТУАЛЬНАЯ ТОЧКА: сегмент $segIdx, offset ${offset}м');
        print('[H2] F_virtual = $fVirtual');
        print('=' * 80);
      }
      
      // Генерация P_set для расширенной системы
      final List<List<double>> pSetExt = generatePSet(fExtended, tExtended, settings);
      
      // Генерация решений для данной виртуальной позиции (используем H0 логику)
      for (double pV in pSetExt[vIdxExt]) {
        final double sV = fExtended[vIdxExt] - pV;
        final tolerance = DrainageTypes.tolerance['V']!;
        final int minS = tolerance[0];
        final int maxS = tolerance[1];
        
        if (sV < minS || sV > maxS) {
          continue;
        }
        
        // Левый сегмент
        if (vIdxExt > 0) {
          final leftSegments = generateSegmentBnb(
            F: fExtended,
            T: tExtended,
            L: lExtended,
            pSet: pSetExt,
            startIdx: 0,
            endIdx: vIdxExt - 1,
            direction: 'left',
            settings: settings,
            debug: debug,
          );
          
          for (List<double> leftSegment in leftSegments) {
            final double pLeftLast = leftSegment.last;
            final double kToV = (pLeftLast - pV).abs() / lExtended[vIdxExt - 1];
            
            if (kToV < settings.kMin) {
              continue;
            }
            
            // Правый сегмент
            if (vIdxExt < nExt - 1) {
              final rightSegments = generateSegmentBnb(
                F: fExtended,
                T: tExtended,
                L: lExtended,
                pSet: pSetExt,
                startIdx: vIdxExt + 1,
                endIdx: nExt - 1,
                direction: 'right',
                settings: settings,
                debug: debug,
              );
              
              for (List<double> rightSegment in rightSegments) {
                final double pRightFirst = rightSegment.first;
                final double kFromV = (pV - pRightFirst).abs() / lExtended[vIdxExt];
                
                if (kFromV < settings.kMin) {
                  continue;
                }
                
                // Сборка полного решения
                final List<double> fullSolution = [
                  ...leftSegment,
                  pV,
                  ...rightSegment,
                ];
                
                // Финальная валидация
                if (isSolutionValid(
                  P: fullSolution,
                  vIndex: vIdxExt,
                  F: fExtended,
                  T: tExtended,
                  L: lExtended,
                  settings: settings,
                  debug: debug,
                )) {
                  // Сохраняем решение с метаданными о виртуальной точке
                  solutions.add(Solution(
                    P: fullSolution,
                    vIndex: vIdxExt,
                    score: 0,
                    F: fExtended,
                    T: tExtended,
                    L: lExtended,
                    metadata: DrainageMetadata(
                      virtual: true,
                      segment: segIdx,
                      offset: offset,
                    ),
                  ));
                  
                  if (debug) {
                    print('[H2] ✓ Решение добавлено!');
                  }
                }
              }
            } else {
              // Только левый сегмент + водораздел
              final List<double> fullSolution = [...leftSegment, pV];
              
              if (isSolutionValid(
                P: fullSolution,
                vIndex: vIdxExt,
                F: fExtended,
                T: tExtended,
                L: lExtended,
                settings: settings,
                debug: debug,
              )) {
                solutions.add(Solution(
                  P: fullSolution,
                  vIndex: vIdxExt,
                  score: 0,
                  F: fExtended,
                  T: tExtended,
                  L: lExtended,
                  metadata: DrainageMetadata(
                    virtual: true,
                    segment: segIdx,
                    offset: offset,
                  ),
                ));
              }
            }
          }
        } else {
          // Водораздел в начале
          if (vIdxExt < nExt - 1) {
            final rightSegments = generateSegmentBnb(
              F: fExtended,
              T: tExtended,
              L: lExtended,
              pSet: pSetExt,
              startIdx: vIdxExt + 1,
              endIdx: nExt - 1,
              direction: 'right',
              settings: settings,
              debug: debug,
            );
            
            for (List<double> rightSegment in rightSegments) {
              final double pRightFirst = rightSegment.first;
              final double kFromV = (pV - pRightFirst).abs() / lExtended[vIdxExt];
              
              if (kFromV < settings.kMin) {
                continue;
              }
              
              final List<double> fullSolution = [pV, ...rightSegment];
              
              if (isSolutionValid(
                P: fullSolution,
                vIndex: vIdxExt,
                F: fExtended,
                T: tExtended,
                L: lExtended,
                settings: settings,
                debug: debug,
              )) {
                solutions.add(Solution(
                  P: fullSolution,
                  vIndex: vIdxExt,
                  score: 0,
                  F: fExtended,
                  T: tExtended,
                  L: lExtended,
                  metadata: DrainageMetadata(
                    virtual: true,
                    segment: segIdx,
                    offset: offset,
                  ),
                ));
              }
            }
          }
        }
      }
    }
    
    if (debug) {
      print('\n[H2] Найдено ${solutions.length} решений');
    }
    
    return solutions;
  }
}
