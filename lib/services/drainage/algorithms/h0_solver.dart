/// Модуль drainage_core - Алгоритм H0 (фиксированный водораздел)
/// Часть системы расчёта дренажного профиля

import '../models/types.dart';
import '../models/settings.dart';
import 'solver_base.dart';

/// Решатель H0 - работа с фиксированным водоразделом (тип 'V')
class H0Solver {
  /// Решение с фиксированным водоразделом
  static List<Solution> solveH0({
    required List<double> F,
    required List<String> T,
    required List<double> L,
    required List<List<double>> pSet,
    required DrainageSettings settings,
    bool debug = false,
  }) {
    final List<Solution> solutions = [];
    final int vIndex = T.indexOf('V');
    final int N = F.length;
    
    if (vIndex == -1) return solutions;
    
    // Перебираем все допустимые P для водораздела
    for (double pV in pSet[vIndex]) {
      final double sV = F[vIndex] - pV;
      final tolerance = DrainageTypes.tolerance['V']!;
      
      if (sV < tolerance[0] || sV > tolerance[1]) {
        continue;
      }
      
      // Генерация левого сегмента (от 0 до V-1)
      if (vIndex > 0) {
        final leftSegments = generateSegmentBnb(
          F: F,
          T: T,
          L: L,
          pSet: pSet,
          startIdx: 0,
          endIdx: vIndex - 1,
          direction: 'left',
          settings: settings,
          debug: debug,
        );
        
        for (List<double> leftSegment in leftSegments) {
          // Проверка уклона к водоразделу
          final double pLeftLast = leftSegment.last;
          final double kToV = (pLeftLast - pV).abs() / L[vIndex - 1];
          
          if (kToV < settings.kMin) {
            continue;
          }
          
          // Генерация правого сегмента (от V+1 до N-1)
          if (vIndex < N - 1) {
            final rightSegments = generateSegmentBnb(
              F: F,
              T: T,
              L: L,
              pSet: pSet,
              startIdx: vIndex + 1,
              endIdx: N - 1,
              direction: 'right',
              settings: settings,
              debug: debug,
            );
            
            for (List<double> rightSegment in rightSegments) {
              // Проверка уклона от водораздела
              final double pRightFirst = rightSegment.first;
              final double kFromV = (pV - pRightFirst).abs() / L[vIndex];
              
              if (kFromV < settings.kMin) {
                continue;
              }
              
              // Сборка полного решения
              final List<double> fullSolution = [
                ...leftSegment,
                pV,
                ...rightSegment,
              ];
              
              // Финальная проверка
              if (isSolutionValid(
                P: fullSolution,
                vIndex: vIndex,
                F: F,
                T: T,
                L: L,
                settings: settings,
                debug: debug,
              )) {
                solutions.add(Solution(
                  P: fullSolution,
                  vIndex: vIndex,
                  score: 0,
                  F: F,
                  T: T,
                  L: L,
                ));
              }
            }
          } else {
            // Только левый сегмент + водораздел
            final List<double> fullSolution = [...leftSegment, pV];
            
            if (isSolutionValid(
              P: fullSolution,
              vIndex: vIndex,
              F: F,
              T: T,
              L: L,
              settings: settings,
              debug: debug,
            )) {
              solutions.add(Solution(
                P: fullSolution,
                vIndex: vIndex,
                score: 0,
                F: F,
                T: T,
                L: L,
              ));
            }
          }
        }
      } else {
        // Водораздел в начале
        if (vIndex < N - 1) {
          final rightSegments = generateSegmentBnb(
            F: F,
            T: T,
            L: L,
            pSet: pSet,
            startIdx: vIndex + 1,
            endIdx: N - 1,
            direction: 'right',
            settings: settings,
            debug: debug,
          );
          
          for (List<double> rightSegment in rightSegments) {
            final double pRightFirst = rightSegment.first;
            final double kFromV = (pV - pRightFirst).abs() / L[vIndex];
            
            if (kFromV < settings.kMin) {
              continue;
            }
            
            final List<double> fullSolution = [pV, ...rightSegment];
            
            if (isSolutionValid(
              P: fullSolution,
              vIndex: vIndex,
              F: F,
              T: T,
              L: L,
              settings: settings,
              debug: debug,
            )) {
              solutions.add(Solution(
                P: fullSolution,
                vIndex: vIndex,
                score: 0,
                F: F,
                T: T,
                L: L,
              ));
            }
          }
        }
      }
    }
    
    return solutions;
  }
}
