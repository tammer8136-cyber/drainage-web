/// Модуль drainage_core - Входные данные
/// Часть системы расчёта дренажного профиля

class DrainageInput {
  /// Отметки поверхности (мм)
  final List<double> F;
  
  /// Типы лотков
  final List<String> T;
  
  /// Длины сегментов (м)
  final List<double> L;
  
  DrainageInput({
    required this.F,
    required this.T,
    required this.L,
  });
  
  /// Создание из JSON
  factory DrainageInput.fromJson(Map<String, dynamic> json) {
    return DrainageInput(
      F: (json['F'] as List).map((e) => (e as num).toDouble()).toList(),
      T: (json['T'] as List).map((e) => e as String).toList(),
      L: (json['L'] as List).map((e) => (e as num).toDouble()).toList(),
    );
  }
  
  /// Преобразование в JSON
  Map<String, dynamic> toJson() => {
    'F': F,
    'T': T,
    'L': L,
  };
  
  /// Количество точек
  int get N => F.length;
}
