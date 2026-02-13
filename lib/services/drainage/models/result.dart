/// Модуль drainage_core - Результаты расчёта
/// Часть системы расчёта дренажного профиля

class DrainageMetadata {
  /// Виртуальный водораздел?
  final bool virtual;
  
  /// Номер сегмента (для виртуального)
  final int? segment;
  
  /// Смещение в сегменте (для виртуального)
  final int? offset;
  
  DrainageMetadata({
    required this.virtual,
    this.segment,
    this.offset,
  });
  
  Map<String, dynamic> toJson() => {
    'virtual': virtual,
    'segment': segment,
    'offset': offset,
  };
  
  factory DrainageMetadata.fromJson(Map<String, dynamic> json) {
    return DrainageMetadata(
      virtual: json['virtual'] as bool,
      segment: json['segment'] as int?,
      offset: json['offset'] as int?,
    );
  }
}

class DrainageResult {
  /// Статус расчёта
  final String status; // 'РЕШАЕМО' или 'НЕРЕШАЕМО'
  
  /// Проектные отметки (если решаемо)
  final List<double>? solution;
  
  /// Индекс водораздела (если решаемо)
  final int? vIndex;
  
  /// Балл решения (если решаемо)
  final double? score;
  
  /// Общее количество найденных решений (если решаемо)
  final int? totalSolutions;
  
  /// Средний слой асфальта (интегральный метод)
  final double? averageLayer;
  
  /// Время расчёта (секунды)
  final double computationTime;
  
  /// Расширенные F (для H2)
  final List<double>? F;
  
  /// Расширенные T (для H2)
  final List<String>? T;
  
  /// Расширенные L (для H2)
  final List<double>? L;
  
  /// Метаданные (для H2)
  final DrainageMetadata? metadata;
  
  /// Сообщение об ошибке (если нерешаемо)
  final String? error;
  
  DrainageResult({
    required this.status,
    this.solution,
    this.vIndex,
    this.score,
    this.totalSolutions,
    this.averageLayer,
    required this.computationTime,
    this.F,
    this.T,
    this.L,
    this.metadata,
    this.error,
  });
  
  /// Успешное решение
  factory DrainageResult.success({
    required List<double> solution,
    required int vIndex,
    required double score,
    required int totalSolutions,
    double? averageLayer,
    required double computationTime,
    List<double>? F,
    List<String>? T,
    List<double>? L,
    DrainageMetadata? metadata,
  }) {
    return DrainageResult(
      status: 'РЕШАЕМО',
      solution: solution,
      vIndex: vIndex,
      score: score,
      totalSolutions: totalSolutions,
      averageLayer: averageLayer,
      computationTime: computationTime,
      F: F,
      T: T,
      L: L,
      metadata: metadata,
    );
  }
  
  /// Ошибка или нерешаемо
  factory DrainageResult.error({
    required String error,
    required double computationTime,
  }) {
    return DrainageResult(
      status: 'НЕРЕШАЕМО',
      error: error,
      computationTime: computationTime,
    );
  }
  
  /// Решение найдено?
  bool get isSolvable => status == 'РЕШАЕМО';
  
  /// Преобразование в JSON
  Map<String, dynamic> toJson() => {
    'status': status,
    'solution': solution,
    'v_index': vIndex,
    'score': score,
    'total_solutions': totalSolutions,
    'average_layer': averageLayer,
    'computation_time': computationTime,
    'F': F,
    'T': T,
    'L': L,
    'metadata': metadata?.toJson(),
    'error': error,
  };
  
  /// Создание из JSON
  factory DrainageResult.fromJson(Map<String, dynamic> json) {
    return DrainageResult(
      status: json['status'] as String,
      solution: json['solution'] != null 
        ? (json['solution'] as List).map((e) => (e as num).toDouble()).toList()
        : null,
      vIndex: json['v_index'] as int?,
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      totalSolutions: json['total_solutions'] as int?,
      averageLayer: json['average_layer'] != null ? (json['average_layer'] as num).toDouble() : null,
      computationTime: (json['computation_time'] as num).toDouble(),
      F: json['F'] != null
        ? (json['F'] as List).map((e) => (e as num).toDouble()).toList()
        : null,
      T: json['T'] != null
        ? (json['T'] as List).map((e) => e as String).toList()
        : null,
      L: json['L'] != null
        ? (json['L'] as List).map((e) => (e as num).toDouble()).toList()
        : null,
      metadata: json['metadata'] != null
        ? DrainageMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
        : null,
      error: json['error'] as String?,
    );
  }
}
