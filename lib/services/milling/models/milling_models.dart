/// Перепрофилирование края под фрезу — модели данных.

import 'milling_types.dart';

/// Настройки расчёта фрезы. Все допуски/пороги гибкие (редактируются),
/// как и в дренажном расчёте.
class MillingSettings {
  double kMin;
  int delta;
  double overlay;
  double targetCut;
  Map<String, List<int>> tolerance;

  /// Допустимое оголение борта, мм — единый диапазон для всех точек,
  /// где борт введён.
  double bortExposureMin;
  double bortExposureMax;

  /// Проверять ли оголение борта. Когда выключено — борт можно вводить
  /// для справки, но коридор он не сужает.
  bool checkBortExposure;

  MillingSettings({
    double? kMin,
    int? delta,
    double? overlay,
    double? targetCut,
    Map<String, List<int>>? tolerance,
    double? bortExposureMin,
    double? bortExposureMax,
    bool? checkBortExposure,
  })  : kMin = kMin ?? MillingTypes.kMin,
        delta = delta ?? MillingTypes.delta,
        overlay = overlay ?? MillingTypes.overlay,
        targetCut = targetCut ?? MillingTypes.targetCut,
        tolerance = tolerance ??
            MillingTypes.tolerance.map((k, v) => MapEntry(k, List<int>.from(v))),
        bortExposureMin = bortExposureMin ?? MillingTypes.bortExposureMin,
        bortExposureMax = bortExposureMax ?? MillingTypes.bortExposureMax,
        checkBortExposure = checkBortExposure ?? true;

  factory MillingSettings.defaults() => MillingSettings();

  Map<String, dynamic> toJson() => {
        'kMin': kMin,
        'delta': delta,
        'overlay': overlay,
        'targetCut': targetCut,
        'tolerance': tolerance,
        'bortExposureMin': bortExposureMin,
        'bortExposureMax': bortExposureMax,
        'checkBortExposure': checkBortExposure,
      };

  factory MillingSettings.fromJson(Map<String, dynamic> json) {
    Map<String, List<int>>? tol;
    if (json['tolerance'] != null) {
      tol = (json['tolerance'] as Map).map(
        (k, v) => MapEntry(k.toString(), (v as List).map((e) => (e as num).toInt()).toList()),
      );
    }
    return MillingSettings(
      kMin: (json['kMin'] as num?)?.toDouble(),
      delta: (json['delta'] as num?)?.toInt(),
      overlay: (json['overlay'] as num?)?.toDouble(),
      targetCut: (json['targetCut'] as num?)?.toDouble(),
      tolerance: tol,
      bortExposureMin: (json['bortExposureMin'] as num?)?.toDouble(),
      bortExposureMax: (json['bortExposureMax'] as num?)?.toDouble(),
      checkBortExposure: json['checkBortExposure'] as bool?,
    );
  }

  String? validate() {
    if (kMin < 0 || kMin > 10) return 'kMin должен быть в диапазоне [0, 10]';
    if (delta < 1 || delta > 20) return 'delta должен быть в диапазоне [1, 20]';
    if (overlay < 0 || overlay > 200) return 'Толщина укладки вне диапазона [0, 200]';
    if (targetCut < 0 || targetCut > 300) return 'Целевой срез вне диапазона [0, 300]';
    for (final e in tolerance.entries) {
      if (e.value.length != 2) return 'Допуск ${e.key}: нужно два значения';
      if (e.value[0] > e.value[1]) return 'Допуск ${e.key}: минимум больше максимума';
    }
    if (bortExposureMin > bortExposureMax) {
      return 'Оголение борта: минимум больше максимума';
    }
    return null;
  }
}

/// Одна станция: пара «ось + край», расстояние между ними, борт.
/// Все отметки — отсчёты по рейке, мм.
class MillingStation {
  /// Отсчёт по краю (перепроектируется)
  double fEdge;

  /// Отсчёт по оси (НЕ перепроектируется, остаётся как есть)
  double fAxis;

  /// Режим оси: 'A' — снято по асфальту, 'F' — снято по фрезе
  /// (эквивалент по асфальту = отсчёт − overlay: сострижено ⇒ ниже ⇒
  /// отсчёт больше, значит асфальт выше на overlay).
  String axisMode;

  /// Режим края — имеет смысл только для примыкания (PR), реперной точки,
  /// от которой ведётся расчёт:
  ///   'A' — примыкаемся к существующему асфальту: режем ровно на толщину
  ///         укладки, чтобы новое покрытие легло заподлицо, без ступеньки;
  ///   'F' — примыкаемся к уже отфрезерованной поверхности: резать нечего,
  ///         срез 0, слой ложится прямо на неё.
  String edgeMode;

  /// Отсчёт по борту (для проверки оголения). null — борта нет/не меряли.
  double? fBort;

  /// Поперечное расстояние ось→край, м (плывёт по станциям)
  double crossL;

  /// Продольное расстояние до следующей станции, м (у последней — 0)
  double length;

  /// Тип точки: 'O' | 'DK'
  String type;

  MillingStation({
    required this.fEdge,
    required this.fAxis,
    required this.crossL,
    required this.length,
    required this.type,
    this.axisMode = 'A',
    this.edgeMode = 'A',
    this.fBort,
  });

  /// Отсчёт по оси, приведённый к асфальту (с учётом режима F/A)
  double axisAsAsphalt(double overlay) =>
      axisMode == 'F' ? fAxis - overlay : fAxis;

  Map<String, dynamic> toJson() => {
        'fEdge': fEdge,
        'fAxis': fAxis,
        'axisMode': axisMode,
        'edgeMode': edgeMode,
        'fBort': fBort,
        'crossL': crossL,
        'length': length,
        'type': type,
      };

  factory MillingStation.fromJson(Map<String, dynamic> json) => MillingStation(
        fEdge: (json['fEdge'] as num).toDouble(),
        fAxis: (json['fAxis'] as num).toDouble(),
        axisMode: json['axisMode'] as String? ?? 'A',
        edgeMode: json['edgeMode'] as String? ?? 'A',
        fBort: (json['fBort'] as num?)?.toDouble(),
        crossL: (json['crossL'] as num).toDouble(),
        length: (json['length'] as num).toDouble(),
        type: json['type'] as String,
      );
}

/// Узел результата — станция или вставленный виртуальный водораздел.
class MillingNode {
  final double along;
  final double fEdge;
  final double fAxis;
  final double? fBort;
  final double crossL;
  final String type; // 'O' | 'DK' | 'WD'
  final bool isVirtual;

  /// Проектный отсчёт линии среза (до укладки)
  final double cutLine;

  MillingNode({
    required this.along,
    required this.fEdge,
    required this.fAxis,
    required this.crossL,
    required this.type,
    required this.isVirtual,
    required this.cutLine,
    this.fBort,
  });

  /// Глубина фрезеровки, мм
  double get cutDepth => cutLine - fEdge;

  /// Итоговая проектная отметка после укладки (отсчёт по рейке)
  double finalProject(double overlay) => cutLine - overlay;

  /// Поперечный уклон ось→край, ‰ (по итоговой проектной отметке края)
  double crossSlope(double overlay) =>
      crossL > 0 ? (finalProject(overlay) - fAxis) / crossL : 0.0;

  /// Оголение борта, мм (Z_борт − Z_проект после укладки)
  double? bortExposure(double overlay) =>
      fBort == null ? null : finalProject(overlay) - fBort!;

  Map<String, dynamic> toJson() => {
        'along': along,
        'fEdge': fEdge,
        'fAxis': fAxis,
        'fBort': fBort,
        'crossL': crossL,
        'type': type,
        'isVirtual': isVirtual,
        'cutLine': cutLine,
      };
}

class MillingResult {
  final String status; // 'РЕШАЕМО' | 'НЕРЕШАЕМО'
  final List<MillingNode> nodes;
  final int? watershedIndex;
  final String algorithm; // 'H3' | 'H2' | '-'
  final double score;
  final double computationTime;
  final String? error;
  final double overlay;

  /// Реально применённые значения — чтобы экран результата проверял по
  /// ним, а не по константам по умолчанию (пользователь мог их изменить).
  final double targetCut;
  final double bortExposureMin;
  final double bortExposureMax;
  final bool checkBortExposure;

  MillingResult({
    required this.status,
    required this.nodes,
    required this.algorithm,
    required this.score,
    required this.computationTime,
    required this.overlay,
    required this.targetCut,
    required this.bortExposureMin,
    required this.bortExposureMax,
    required this.checkBortExposure,
    this.watershedIndex,
    this.error,
  });

  bool get isSolvable => status == 'РЕШАЕМО';

  factory MillingResult.error(String message, double time, double overlay) =>
      MillingResult(
        status: 'НЕРЕШАЕМО',
        nodes: const [],
        algorithm: '-',
        score: double.infinity,
        computationTime: time,
        overlay: overlay,
        targetCut: MillingTypes.targetCut,
        bortExposureMin: MillingTypes.bortExposureMin,
        bortExposureMax: MillingTypes.bortExposureMax,
        checkBortExposure: true,
        error: message,
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'algorithm': algorithm,
        'score': score.isFinite ? score : null,
        'watershed_index': watershedIndex,
        'computation_time': computationTime,
        'overlay': overlay,
        'target_cut': targetCut,
        'bort_min': bortExposureMin,
        'bort_max': bortExposureMax,
        'check_bort': checkBortExposure,
        'error': error,
        'nodes': nodes.map((n) => n.toJson()).toList(),
      };

  factory MillingResult.fromJson(Map<String, dynamic> json) => MillingResult(
        status: json['status'] as String,
        algorithm: json['algorithm'] as String? ?? '-',
        score: (json['score'] as num?)?.toDouble() ?? double.infinity,
        watershedIndex: json['watershed_index'] as int?,
        computationTime: (json['computation_time'] as num?)?.toDouble() ?? 0.0,
        overlay: (json['overlay'] as num?)?.toDouble() ?? MillingTypes.overlay,
        targetCut: (json['target_cut'] as num?)?.toDouble() ?? MillingTypes.targetCut,
        bortExposureMin:
            (json['bort_min'] as num?)?.toDouble() ?? MillingTypes.bortExposureMin,
        bortExposureMax:
            (json['bort_max'] as num?)?.toDouble() ?? MillingTypes.bortExposureMax,
        checkBortExposure: json['check_bort'] as bool? ?? true,
        error: json['error'] as String?,
        nodes: ((json['nodes'] as List?) ?? [])
            .map((e) => MillingNode(
                  along: (e['along'] as num).toDouble(),
                  fEdge: (e['fEdge'] as num).toDouble(),
                  fAxis: (e['fAxis'] as num).toDouble(),
                  fBort: (e['fBort'] as num?)?.toDouble(),
                  crossL: (e['crossL'] as num).toDouble(),
                  type: e['type'] as String,
                  isVirtual: e['isVirtual'] as bool,
                  cutLine: (e['cutLine'] as num).toDouble(),
                ))
            .toList(),
      );
}
