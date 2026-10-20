/// Перепрофилирование края под фрезу — монотонная цепочка (общая основа
/// для H3 и для каждой ветки H2).
///
/// Работаем в отсчётах по рейке: «вниз по склону» = отсчёт РАСТЁТ.
/// Цепочка всегда решается в направлении «от высокой точки к низкой»,
/// то есть P[i+1] − P[i] >= kMin * L[i].

import 'dart:math' as math;
import '../models/milling_models.dart';
import '../models/milling_types.dart';

class ChainSolution {
  final List<double> cutLine;
  final double cost;
  ChainSolution(this.cutLine, this.cost);
}

/// Штраф за продольный уклон: ноль везде выше kMin+margin, небольшой
/// штраф в узкой зоне перестраховки сразу над kMin. Ниже kMin — не
/// допускается вовсе (отсекается при генерации переходов).
double slopeCost(double slope, double kMin, double margin, double penalty) {
  final s = slope.abs();
  if (s < kMin - 1e-9) return double.infinity;
  if (s <= kMin + margin) return penalty;
  return 0.0;
}

/// Стоимость узла — отклонение среза от целевого (обычно 50мм),
/// взвешенное по длине. НЕ «чем меньше срез, тем лучше».
double nodeCost({
  required double cutValue,
  required double fEdge,
  required double targetCut,
  required double weight,
}) {
  final cut = cutValue - fEdge;
  return (cut - targetCut).abs() * weight;
}

/// Сужение коридора по kMin с обоих концов. Возвращает null, если
/// коридор где-то пуст (цепочка нерешаема).
List<List<double>>? tightenCorridor({
  required List<double> lo,
  required List<double> hi,
  required List<double> dist,
  required double kMin,
}) {
  final n = lo.length;
  final l = List<double>.from(lo);
  final h = List<double>.from(hi);

  for (int i = 1; i < n; i++) {
    final minStep = kMin * dist[i - 1];
    l[i] = math.max(l[i], l[i - 1] + minStep);
  }
  for (int i = n - 2; i >= 0; i--) {
    final minStep = kMin * dist[i];
    h[i] = math.min(h[i], h[i + 1] - minStep);
  }
  for (int i = 0; i < n; i++) {
    if (l[i] > h[i] + 1e-9) return null;
  }
  return [l, h];
}

/// Решение монотонной цепочки динамическим программированием по сетке.
/// [fixedStart] — если задано, P[0] обязан равняться этому значению
/// (используется для веток H2: обе ветки стартуют из водораздела).
ChainSolution? solveChain({
  required List<double> lo,
  required List<double> hi,
  required List<double> dist,
  required List<double> fEdge,
  required List<double> weight,
  required MillingSettings settings,
  double? fixedStart,
}) {
  final n = lo.length;
  if (n == 0) return null;
  if (n == 1) {
    final v = fixedStart ?? lo[0];
    if (v < lo[0] - 1e-9 || v > hi[0] + 1e-9) return null;
    return ChainSolution([v], nodeCost(
      cutValue: v, fEdge: fEdge[0], targetCut: settings.targetCut, weight: weight[0],
    ));
  }

  final localLo = List<double>.from(lo);
  final localHi = List<double>.from(hi);
  if (fixedStart != null) {
    if (fixedStart < lo[0] - 1e-9 || fixedStart > hi[0] + 1e-9) return null;
    localLo[0] = fixedStart;
    localHi[0] = fixedStart;
  }

  final tightened = tightenCorridor(
    lo: localLo, hi: localHi, dist: dist, kMin: settings.kMin,
  );
  if (tightened == null) return null;
  final tl = tightened[0];
  final th = tightened[1];

  List<double> candidatesFor(int i) {
    if (th[i] - tl[i] < 1e-9) return [tl[i]];
    final out = <double>[];

    // Сетку привязываем к отсчёту КРАЯ, а не к нижней границе коридора.
    // Низ могут поднять поперечник или оголение борта на произвольную
    // величину — и тогда вся сетка съезжает вместе с ним, а круглые
    // значения среза (кратные delta, в том числе ровно целевые 50мм) в
    // перебор не попадают вообще. Именно из-за этого расширение допуска
    // могло УХУДШИТЬ результат: при узком коридоре нужное значение
    // случайно спасалось тем, что верхняя граница добавляется отдельно.
    final double anchor = fEdge[i];
    final int firstStep = ((tl[i] - anchor) / settings.delta).ceil();
    double v = anchor + firstStep * settings.delta;

    // Сама нижняя граница тоже остаётся кандидатом — она может быть
    // единственным допустимым значением у края коридора.
    if (v > tl[i] + 1e-9) out.add(tl[i]);

    while (v <= th[i] + 1e-9) {
      out.add(v);
      v += settings.delta;
    }

    if (out.isEmpty || out.last < th[i] - 1e-9) out.add(th[i]);
    return out;
  }

  final cands = List.generate(n, candidatesFor);

  var dpCost = <double>[
    for (final v in cands[0])
      nodeCost(cutValue: v, fEdge: fEdge[0], targetCut: settings.targetCut, weight: weight[0]),
  ];
  final backPtr = <List<int>>[];

  for (int i = 1; i < n; i++) {
    final d = dist[i - 1];
    final minStep = settings.kMin * d;
    final newCost = List<double>.filled(cands[i].length, double.infinity);
    final newPrev = List<int>.filled(cands[i].length, -1);

    for (int pi = 0; pi < cands[i - 1].length; pi++) {
      final base = dpCost[pi];
      if (!base.isFinite) continue;
      final zPrev = cands[i - 1][pi];
      for (int ci = 0; ci < cands[i].length; ci++) {
        final zCur = cands[i][ci];
        final drop = zCur - zPrev;
        if (drop < minStep - 1e-9) continue;
        final slope = drop / d;
        final sc = slopeCost(
          slope,
          settings.kMin,
          MillingTypes.slopeSafeMargin,
          MillingTypes.slopePenaltyNear,
        );
        if (!sc.isFinite) continue;
        final total = base +
            sc +
            nodeCost(
              cutValue: zCur,
              fEdge: fEdge[i],
              targetCut: settings.targetCut,
              weight: weight[i],
            );
        if (total < newCost[ci]) {
          newCost[ci] = total;
          newPrev[ci] = pi;
        }
      }
    }
    dpCost = newCost;
    backPtr.add(newPrev);
  }

  double best = double.infinity;
  int bestIdx = -1;
  for (int i = 0; i < dpCost.length; i++) {
    if (dpCost[i] < best) {
      best = dpCost[i];
      bestIdx = i;
    }
  }
  if (bestIdx < 0 || !best.isFinite) return null;

  final idx = <int>[bestIdx];
  var cur = bestIdx;
  for (int i = n - 1; i > 0; i--) {
    cur = backPtr[i - 1][cur];
    if (cur < 0) return null;
    idx.add(cur);
  }
  final ordered = idx.reversed.toList();
  final line = List<double>.generate(n, (i) => cands[i][ordered[i]]);
  return ChainSolution(line, best);
}
