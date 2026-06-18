/// Модуль drainage_core - Базовые классы и утилиты для алгоритмов
/// Часть системы расчёта дренажного профиля

import '../models/types.dart';
import '../models/result.dart';
import '../models/settings.dart';

// ============================================================================
// ВНУТРЕННИЕ КЛАССЫ
// ============================================================================

/// Внутренний класс для хранения решения
class Solution {
  final List<double> P;
  final int vIndex;
  final double score;
  final double? averageLayer;
  final List<double>? F;
  final List<String>? T;
  final List<double>? L;
  final DrainageMetadata? metadata;
  
  Solution({
    required this.P,
    required this.vIndex,
    required this.score,
    this.averageLayer,
    this.F,
    this.T,
    this.L,
    this.metadata,
  });
}

/// Внутренний класс для виртуальных позиций водораздела
class VirtualPosition {
  final int segment;
  final int offset;
  final double cumulative;
  
  VirtualPosition({
    required this.segment,
    required this.offset,
    required this.cumulative,
  });
}

// ============================================================================
// ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ============================================================================

/// Генерация P_set (множество допустимых проектных отметок)
List<List<double>> generatePSet(
  List<double> F,
  List<String> T,
  DrainageSettings settings,
) {
  final List<List<double>> pSet = [];
  
  for (int i = 0; i < F.length; i++) {
    final tolerance = settings.tolerance[T[i]]!;
    final int minS = tolerance[0];
    final int maxS = tolerance[1];
    
    // Генерируем значения S с шагом delta
    final List<int> sValues = [];
    for (int s = minS; s <= maxS; s += settings.delta) {
      sValues.add(s);
    }
    
    // Если диапазон пустой, берём минимум
    if (sValues.isEmpty) {
      sValues.add(minS);
    }
    
    // Вычисляем P = F - S
    final List<double> pValues = [];
    for (int s in sValues) {
      final double pVal = F[i] - s;
      final double sCheck = F[i] - pVal;
      
      // Проверяем, что S в допуске
      if (sCheck >= minS && sCheck <= maxS) {
        pValues.add(pVal);
      }
    }
    
    pSet.add(pValues);
  }
  
  return pSet;
}

/// Вычислить прошедшее время в секундах
double elapsedSeconds(DateTime startTime) {
  return DateTime.now().difference(startTime).inMicroseconds / 1000000.0;
}

/// Проверка валидности решения
bool isSolutionValid({
  required List<double> P,
  required int vIndex,
  required List<double> F,
  required List<String> T,
  required List<double> L,
  required DrainageSettings settings,
  bool debug = false,
}) {
  final int N = P.length;
  
  // Проверка всех слоёв
  for (int i = 0; i < N; i++) {
    final double S = F[i] - P[i];
    final tolerance = DrainageTypes.tolerance[T[i]]!;
    final int minS = tolerance[0];
    final int maxS = tolerance[1];
    
    if (S < minS || S > maxS) {
      if (debug) {
        print('Invalid layer at $i: S=$S not in [$minS, $maxS]');
      }
      return false;
    }
  }
  
  // Проверка всех уклонов с учётом направления
  for (int i = 0; i < N - 1; i++) {
    double k;
    
    if (i < vIndex) {
      // Левый сегмент: уклон к водоразделу (P убывает)
      k = (P[i] - P[i + 1]) / L[i];
    } else {
      // Правый сегмент: уклон от водораздела (P возрастает)
      k = (P[i + 1] - P[i]) / L[i];
    }
    
    if (k < settings.kMin) {
      if (debug && k < 0) {
        print('Counterslope at $i: k=$k');
      }
      return false;
    }
  }
  
  return true;
}

/// Генерация сегмента с Branch & Bound — callback-версия с буфером.
/// Не накапливает все решения в памяти — вызывает [onSolution] для каждого найденного.
/// Буфер переиспользуется — нет аллокации [...currentP, p] на каждой итерации.
void generateSegmentBnb({
  required List<double> F,
  required List<String> T,
  required List<double> L,
  required List<List<double>> pSet,
  required int startIdx,
  required int endIdx,
  required String direction,
  required DrainageSettings settings,
  required void Function(List<double> result) onSolution,
  bool debug = false,
}) {
  final int segLen = endIdx - startIdx + 1;
  final List<double> buffer = List.filled(segLen, 0.0);

  void backtrack(int idx, int depth) {
    if (idx > endIdx) {
      onSolution(List<double>.from(buffer));
      return;
    }

    for (final double pCurrent in pSet[idx]) {
      final double sCurrent = F[idx] - pCurrent;
      final tol = DrainageTypes.tolerance[T[idx]]!;

      // Отсечение 1: слой
      if (sCurrent < tol[0] || sCurrent > tol[1]) continue;

      // Отсечение 2: уклон с предыдущей точкой
      if (depth > 0) {
        final double pPrev = buffer[depth - 1];
        final double k = direction == 'left'
            ? (pPrev - pCurrent) / L[idx - 1]
            : (pCurrent - pPrev) / L[idx - 1];
        if (k < settings.kMin) continue;
      }

      buffer[depth] = pCurrent;
      backtrack(idx + 1, depth + 1);
    }
  }

  backtrack(startIdx, 0);
}

/// Обёртка над generateSegmentBnb для обратной совместимости.
/// Возвращает все решения списком — использовать только там, где это необходимо
/// (H0, где количество решений обычно мало). Для H2 использовать напрямую с onSolution.
List<List<double>> generateSegmentBnbList({
  required List<double> F,
  required List<String> T,
  required List<double> L,
  required List<List<double>> pSet,
  required int startIdx,
  required int endIdx,
  required String direction,
  required DrainageSettings settings,
  bool debug = false,
}) {
  final results = <List<double>>[];
  generateSegmentBnb(
    F: F, T: T, L: L, pSet: pSet,
    startIdx: startIdx, endIdx: endIdx,
    direction: direction, settings: settings,
    onSolution: results.add,
    debug: debug,
  );
  return results;
}
