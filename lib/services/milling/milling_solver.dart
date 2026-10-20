/// Перепрофилирование края под фрезу — основной солвер.
///
/// H3 — без водораздела (профиль монотонный: отсчёт растёт либо убывает).
/// H2 — с водоразделом (высшая точка, от неё отсчёт растёт в обе стороны).
/// Водораздел может встать как на существующей станции, так и МЕЖДУ ними
/// (виртуальный) — тогда ось/борт/поперечник в этом месте интерполируются.
///
/// Один кусок = максимум один водораздел (работа в поле, небольшие участки;
/// разбиение длинной трассы на куски по анкерам сознательно вне скоупа).

import 'dart:math' as math;
import 'models/milling_models.dart';
import 'models/milling_types.dart';
import 'algorithms/milling_chain.dart';

class _Node {
  double along;
  double fEdge;
  double fAxis;
  double? fBort;
  double crossL;
  String type;
  bool isVirtual;
  String edgeMode;
  _Node({
    required this.along,
    required this.fEdge,
    required this.fAxis,
    required this.crossL,
    required this.type,
    required this.isVirtual,
    this.edgeMode = 'A',
    this.fBort,
  });
}

class MillingSolver {
  /// Коридор допустимых значений линии среза (отсчёт по рейке, мм) в узле.
  /// Сужается тремя независимыми ограничениями:
  ///  1) допуск по толщине среза для типа точки;
  ///  2) оголение борта (жёстко, а не штрафом);
  ///  3) поперечный уклон ось→край — ТОЛЬКО в точке водораздела.
  static List<double>? _corridor(_Node node, MillingSettings s) {
    final tol = s.tolerance[node.type] ?? s.tolerance['O']!;
    double lo = node.fEdge + tol[0];
    double hi = node.fEdge + tol[1];

    // Примыкание к уже отфрезерованной поверхности: резать нечего, срез 0.
    // (Примыкание к асфальту идёт по обычному допуску PR — срез в толщину
    // укладки, чтобы лечь заподлицо.)
    if (node.type == 'PR' && node.edgeMode == 'F') {
      lo = node.fEdge;
      hi = node.fEdge;
    }

    // Оголение борта: min <= (P − overlay) − fBort <= max
    //   ⇒ P >= fBort + min + overlay   и   P <= fBort + max + overlay
    // Применяется к любой точке, где борт введён (без деления по типам).
    if (s.checkBortExposure && node.fBort != null) {
      lo = math.max(lo, node.fBort! + s.bortExposureMin + s.overlay);
      hi = math.min(hi, node.fBort! + s.bortExposureMax + s.overlay);
    }

    if (node.type == 'WD' && node.crossL > 0) {
      // ((P − overlay) − fAxis) / crossL >= hardFloor
      lo = math.max(
        lo,
        node.fAxis + s.overlay + MillingTypes.crossSlopeHardFloor * node.crossL,
      );
    }

    if (lo > hi + 1e-9) return null;
    return [lo, hi];
  }

  static List<double> _weights(List<double> along) {
    final n = along.length;
    final total = along.last - along.first;
    return List<double>.generate(n, (i) {
      double w = 0;
      if (i > 0) w += (along[i] - along[i - 1]) / 2;
      if (i < n - 1) w += (along[i + 1] - along[i]) / 2;
      return total > 0 ? w / total : 1.0;
    });
  }

  static List<double> _dists(List<double> along) =>
      List<double>.generate(along.length - 1, (i) => along[i + 1] - along[i]);

  /// Доп. штраф за поперечный уклон в водоразделе: 0‰ и выше — норма,
  /// между hardFloor и 0 — небольшой штраф (сам hardFloor уже отсечён
  /// коридором).
  static double _crossSlopePenalty(_Node node, double cutValue, MillingSettings s) {
    if (node.type != 'WD' || node.crossL <= 0) return 0.0;
    final slope = ((cutValue - s.overlay) - node.fAxis) / node.crossL;
    if (slope >= -1e-9) return 0.0;
    return MillingTypes.crossSlopePenaltyNear;
  }

  /// Монотонная попытка (H3) в одном направлении.
  /// [reversed] = true — считаем, что отсчёт растёт от конца к началу.
  static ChainSolution? _tryMonotonic(
    List<_Node> nodes,
    MillingSettings s, {
    required bool reversed,
  }) {
    final ordered = reversed ? nodes.reversed.toList() : nodes;
    final along = ordered.map((n) => n.along).toList();
    final normAlong = reversed
        ? along.map((a) => along.first - a).toList()
        : along;

    final corridors = <List<double>>[];
    for (final n in ordered) {
      final c = _corridor(n, s);
      if (c == null) return null;
      corridors.add(c);
    }

    final sol = solveChain(
      lo: corridors.map((c) => c[0]).toList(),
      hi: corridors.map((c) => c[1]).toList(),
      dist: _dists(normAlong),
      fEdge: ordered.map((n) => n.fEdge).toList(),
      weight: _weights(normAlong),
      settings: s,
    );
    if (sol == null) return null;
    return reversed
        ? ChainSolution(sol.cutLine.reversed.toList(), sol.cost)
        : sol;
  }

  /// Полный score собранного профиля — считается один раз по итогу,
  /// а не суммированием кусочных (чтобы ветки H2 сравнивались честно).
  static double _fullScore(List<_Node> nodes, List<double> cut, MillingSettings s) {
    final along = nodes.map((n) => n.along).toList();
    final w = _weights(along);
    double score = 0;
    for (int i = 0; i < nodes.length; i++) {
      score += nodeCost(
        cutValue: cut[i],
        fEdge: nodes[i].fEdge,
        targetCut: s.targetCut,
        weight: w[i],
      );
      score += _crossSlopePenalty(nodes[i], cut[i], s);
    }
    for (int i = 0; i < nodes.length - 1; i++) {
      final d = along[i + 1] - along[i];
      if (d <= 0) continue;
      final slope = (cut[i + 1] - cut[i]).abs() / d;
      final sc = slopeCost(
        slope, s.kMin, MillingTypes.slopeSafeMargin, MillingTypes.slopePenaltyNear,
      );
      if (!sc.isFinite) return double.infinity;
      score += sc;
    }
    return score;
  }

  /// Линейная интерполяция значения в произвольной along-позиции.
  static double _interp(double a0, double a1, double v0, double v1, double a) {
    if ((a1 - a0).abs() < 1e-9) return v0;
    return v0 + (v1 - v0) * (a - a0) / (a1 - a0);
  }

  /// Попытка H2 с водоразделом в конкретной позиции (существующей или
  /// виртуальной). Возвращает собранный профиль + линию среза + score.
  static List<dynamic>? _tryWatershed(
    List<_Node> base,
    MillingSettings s,
    int insertAfter, // индекс станции, ПОСЛЕ которой вставляем (-1 = на месте idx)
    double wAlong,
    int? existingIdx,
  ) {
    final nodes = <_Node>[];

    if (existingIdx != null) {
      for (int i = 0; i < base.length; i++) {
        final b = base[i];
        if (i == existingIdx) {
          nodes.add(_Node(
            along: b.along, fEdge: b.fEdge, fAxis: b.fAxis, fBort: b.fBort,
            crossL: b.crossL, type: 'WD', isVirtual: false,
          ));
        } else {
          nodes.add(b);
        }
      }
    } else {
      final p0 = base[insertAfter];
      final p1 = base[insertAfter + 1];
      final wdNode = _Node(
        along: wAlong,
        fEdge: _interp(p0.along, p1.along, p0.fEdge, p1.fEdge, wAlong),
        fAxis: _interp(p0.along, p1.along, p0.fAxis, p1.fAxis, wAlong),
        fBort: (p0.fBort != null && p1.fBort != null)
            ? _interp(p0.along, p1.along, p0.fBort!, p1.fBort!, wAlong)
            : null,
        crossL: _interp(p0.along, p1.along, p0.crossL, p1.crossL, wAlong),
        type: 'WD',
        isVirtual: true,
      );
      for (int i = 0; i < base.length; i++) {
        nodes.add(base[i]);
        if (i == insertAfter) nodes.add(wdNode);
      }
    }

    final wIdx = nodes.indexWhere((n) => n.type == 'WD');
    if (wIdx <= 0 || wIdx >= nodes.length - 1) return null;

    final wdCorridor = _corridor(nodes[wIdx], s);
    if (wdCorridor == null) return null;

    final along = nodes.map((n) => n.along).toList();
    final weights = _weights(along);

    // Левая ветка: от водораздела к началу (отсчёт растёт в эту сторону).
    final leftNodes = nodes.sublist(0, wIdx + 1).reversed.toList();
    final leftAlong = leftNodes.map((n) => wAlong - n.along).toList();
    final leftWeights = nodes.sublist(0, wIdx + 1).reversed
        .map((n) => weights[nodes.indexOf(n)]).toList();
    final leftCorridors = <List<double>>[];
    for (final n in leftNodes) {
      final c = _corridor(n, s);
      if (c == null) return null;
      leftCorridors.add(c);
    }

    // Правая ветка: от водораздела к концу.
    final rightNodes = nodes.sublist(wIdx);
    final rightAlong = rightNodes.map((n) => n.along - wAlong).toList();
    final rightWeights =
        rightNodes.map((n) => weights[nodes.indexOf(n)]).toList();
    final rightCorridors = <List<double>>[];
    for (final n in rightNodes) {
      final c = _corridor(n, s);
      if (c == null) return null;
      rightCorridors.add(c);
    }

    double bestScore = double.infinity;
    List<double>? bestCut;

    // Перебираем значение в самом водоразделе — обе ветки стартуют из него.
    // Сетка, как и в цепочке, привязана к отсчёту края, а не к низу
    // коридора: поперечник поднимает низ на произвольную величину, и при
    // привязке к нему круглые значения среза в перебор не попадают.
    final wLo = wdCorridor[0];
    final wHi = wdCorridor[1];
    final wCandidates = <double>[];
    final double wAnchor = nodes[wIdx].fEdge;
    final int wFirstStep = ((wLo - wAnchor) / s.delta).ceil();
    double wv = wAnchor + wFirstStep * s.delta;
    if (wv > wLo + 1e-9) wCandidates.add(wLo);
    while (wv <= wHi + 1e-9) {
      wCandidates.add(wv);
      wv += s.delta;
    }
    if (wCandidates.isEmpty || wCandidates.last < wHi - 1e-9) {
      wCandidates.add(wHi);
    }

    for (final zw in wCandidates) {
      final left = solveChain(
        lo: leftCorridors.map((c) => c[0]).toList(),
        hi: leftCorridors.map((c) => c[1]).toList(),
        dist: _dists(leftAlong),
        fEdge: leftNodes.map((n) => n.fEdge).toList(),
        weight: leftWeights,
        settings: s,
        fixedStart: zw,
      );
      if (left == null) continue;

      final right = solveChain(
        lo: rightCorridors.map((c) => c[0]).toList(),
        hi: rightCorridors.map((c) => c[1]).toList(),
        dist: _dists(rightAlong),
        fEdge: rightNodes.map((n) => n.fEdge).toList(),
        weight: rightWeights,
        settings: s,
        fixedStart: zw,
      );
      if (right == null) continue;

      final full = <double>[
        ...left.cutLine.reversed.toList().sublist(0, wIdx),
        ...right.cutLine,
      ];
      if (full.length != nodes.length) continue;

      final score = _fullScore(nodes, full, s);
      if (score < bestScore - 1e-9) {
        bestScore = score;
        bestCut = full;
      }
    }

    if (bestCut == null) return null;
    return [nodes, bestCut, bestScore, wIdx];
  }

  /// Основная точка входа.
  static MillingResult solve({
    required List<MillingStation> stations,
    required MillingSettings settings,
  }) {
    final sw = Stopwatch()..start();

    if (stations.length < 2) {
      return MillingResult.error(
        'Нужно минимум 2 станции', 0.0, settings.overlay,
      );
    }
    final validation = settings.validate();
    if (validation != null) {
      return MillingResult.error(validation, 0.0, settings.overlay);
    }

    // Нулевая/отрицательная длина между станциями: деление на ноль в Dart
    // не падает (даёт Infinity), но уклоны получаются бессмысленными —
    // ловим на входе, а не выдаём тихо неверный результат.
    for (int i = 0; i < stations.length - 1; i++) {
      if (stations[i].length <= 0) {
        return MillingResult.error(
          'Станция $i: расстояние до следующей должно быть больше нуля',
          0.0,
          settings.overlay,
        );
      }
    }

    // Собираем узлы: along из продольных длин, ось приводим к асфальту.
    final along = <double>[0.0];
    for (int i = 0; i < stations.length - 1; i++) {
      along.add(along.last + stations[i].length);
    }
    final base = <_Node>[
      for (int i = 0; i < stations.length; i++)
        _Node(
          along: along[i],
          fEdge: stations[i].fEdge,
          fAxis: stations[i].axisAsAsphalt(settings.overlay),
          fBort: stations[i].fBort,
          crossL: stations[i].crossL,
          type: stations[i].type,
          isVirtual: false,
          edgeMode: stations[i].edgeMode,
        ),
    ];

    MillingResult build(List<_Node> nodes, List<double> cut, double score,
        int? wIdx, String algo) {
      return MillingResult(
        status: 'РЕШАЕМО',
        algorithm: algo,
        score: score,
        watershedIndex: wIdx,
        computationTime: sw.elapsedMicroseconds / 1e6,
        overlay: settings.overlay,
        targetCut: settings.targetCut,
        bortExposureMin: settings.bortExposureMin,
        bortExposureMax: settings.bortExposureMax,
        checkBortExposure: settings.checkBortExposure,
        nodes: [
          for (int i = 0; i < nodes.length; i++)
            MillingNode(
              along: nodes[i].along,
              fEdge: nodes[i].fEdge,
              fAxis: nodes[i].fAxis,
              fBort: nodes[i].fBort,
              crossL: nodes[i].crossL,
              type: nodes[i].type,
              isVirtual: nodes[i].isVirtual,
              cutLine: cut[i],
            ),
        ],
      );
    }

    // --- H3: без водораздела, оба направления ---
    ChainSolution? bestH3;
    for (final rev in [false, true]) {
      final sol = _tryMonotonic(base, settings, reversed: rev);
      if (sol == null) continue;
      final score = _fullScore(base, sol.cutLine, settings);
      if (!score.isFinite) continue;
      if (bestH3 == null || score < bestH3.cost) {
        bestH3 = ChainSolution(sol.cutLine, score);
      }
    }

    // --- H2: водораздел на существующей станции или между станциями ---
    List<_Node>? bestNodes;
    List<double>? bestCut;
    double bestScore = double.infinity;
    int? bestW;

    // Позиция физически высшей точки края (наименьший отсчёт по рейке).
    // При практически равных баллах водораздел ставим ближе к ней, а не
    // туда, где формально на сотую доли балла лучше: сдвиг на метр от
    // реального гребня математически почти ничего не меняет, а на объекте
    // выглядит произволом.
    //
    // Работает только если пик — ВНУТРЕННЯЯ станция: если он на самом
    // краю участка, водораздел туда всё равно не поставить, и тянуть к
    // нему — значит ухудшать срез без всякой пользы.
    int peakIdx = 0;
    double peakF = base.first.fEdge;
    for (int i = 0; i < base.length; i++) {
      if (base[i].fEdge < peakF) {
        peakF = base[i].fEdge;
        peakIdx = i;
      }
    }
    final bool peakIsInterior = peakIdx > 0 && peakIdx < base.length - 1;
    final double peakAlong = base[peakIdx].along;

    // Выбор в ДВА прохода. Раньше был один жадный проход с окном
    // равенства, и у него было два дефекта: (1) если кандидат выигрывал по
    // близости к пику, но с худшим баллом, в результат уходил балл ДРУГОГО
    // кандидата — а он потом сравнивается с H3 и мог нечестно его побить;
    // (2) выбор зависел от порядка перебора: кандидат, проверенный раньше
    // «лучшего», больше не пересматривался, даже если потом оказывался в
    // окне и ближе к пику.
    final candidates = <List<dynamic>>[]; // [score, wAlong, nodes, cut, wIdx]

    for (int i = 1; i < base.length - 1; i++) {
      final r = _tryWatershed(base, settings, -1, base[i].along, i);
      if (r != null) candidates.add([r[2], base[i].along, r[0], r[1], r[3]]);
    }

    for (int seg = 0; seg < base.length - 1; seg++) {
      final segLen = base[seg + 1].along - base[seg].along;
      double off = MillingTypes.watershedPositionStep;
      while (off < segLen - 1e-9) {
        final wAlong = base[seg].along + off;
        final r = _tryWatershed(base, settings, seg, wAlong, null);
        if (r != null) candidates.add([r[2], wAlong, r[0], r[1], r[3]]);
        off += MillingTypes.watershedPositionStep;
      }
    }

    if (candidates.isNotEmpty) {
      // Проход 1: настоящий минимум балла по ВСЕМ кандидатам.
      double minScore = double.infinity;
      for (final c in candidates) {
        final sc = c[0] as double;
        if (sc < minScore) minScore = sc;
      }

      // Проход 2: среди попавших в окно равенства — ближайший к пику
      // (если пик внутренний), иначе просто лучший балл.
      List<dynamic>? pick;
      for (final c in candidates) {
        final sc = c[0] as double;
        if (peakIsInterior) {
          if (sc > minScore + MillingTypes.watershedTieScore) continue;
          final dist = ((c[1] as double) - peakAlong).abs();
          if (pick == null) {
            pick = c;
          } else {
            final pDist = ((pick[1] as double) - peakAlong).abs();
            // при равной дальности — меньший балл
            if (dist < pDist - 1e-9 ||
                ((dist - pDist).abs() < 1e-9 && sc < (pick[0] as double))) {
              pick = c;
            }
          }
        } else {
          if (pick == null || sc < (pick[0] as double)) pick = c;
        }
      }

      if (pick != null) {
        // Балл — ИМЕННО выбранного кандидата, а не минимум по всем.
        bestScore = pick[0] as double;
        bestNodes = pick[2] as List<_Node>;
        bestCut = pick[3] as List<double>;
        bestW = pick[4] as int;
      }
    }

    // --- Выбор лучшего ---
    final hasH2 = bestNodes != null && bestCut != null;
    if (bestH3 != null && (!hasH2 || bestH3.cost <= bestScore)) {
      return build(base, bestH3.cutLine, bestH3.cost, null, 'H3');
    }
    if (bestNodes != null && bestCut != null) {
      return build(bestNodes, bestCut, bestScore, bestW, 'H2');
    }

    return MillingResult.error(
      'Решение не найдено. Коридор сужают ограничения — проверьте их '
      'по очереди:\n'
      '• допуски среза по типам точек;\n'
      '• минимальный уклон ${settings.kMin.toStringAsFixed(1)}‰ '
      '(при плоском рельефе может быть недостижим);\n'
      '${settings.checkBortExposure ? "• оголение борта ${settings.bortExposureMin.toStringAsFixed(0)}–${settings.bortExposureMax.toStringAsFixed(0)} мм (проверка включена);\n" : ""}'
      '• поперечный уклон в водоразделе — если ось оказалась ниже края, '
      'край не может уйти под неё в пределах допуска на срез.',
      sw.elapsedMicroseconds / 1e6,
      settings.overlay,
    );
  }
}
