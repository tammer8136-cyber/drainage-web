/// Модуль drainage_core - Валидация входных данных
/// Часть системы расчёта дренажного профиля

import 'types.dart';
import 'input.dart';

class ValidationResult {
  final bool isValid;
  final String message;
  
  ValidationResult({required this.isValid, required this.message});
  
  factory ValidationResult.ok() => ValidationResult(isValid: true, message: 'OK');
  factory ValidationResult.error(String message) => 
    ValidationResult(isValid: false, message: message);
}

class DrainageValidation {
  /// Валидировать входные данные
  static ValidationResult validate(DrainageInput input) {
    final F = input.F;
    final T = input.T;
    final L = input.L;
    
    // Проверка типов
    if (F.isEmpty) {
      return ValidationResult.error('F не может быть пустым');
    }
    
    if (T.isEmpty) {
      return ValidationResult.error('T не может быть пустым');
    }
    
    if (L.isEmpty && F.length > 1) {
      return ValidationResult.error('L не может быть пустым');
    }
    
    // Проверка отрицательных значений F
    for (int i = 0; i < F.length; i++) {
      if (F[i] < 0) {
        return ValidationResult.error('Все значения F должны быть >= 0');
      }
    }
    
    // Проверка длин сегментов
    for (int i = 0; i < L.length; i++) {
      if (L[i] < 0.5 || L[i] > 25) {
        return ValidationResult.error(
          'Все длины L должны быть в диапазоне [0.5, 25] метров'
        );
      }
    }
    
    // Проверка минимального количества точек
    if (F.length < 3) {
      return ValidationResult.error('Система должна содержать минимум 3 точки');
    }
    
    // Проверка соответствия длин
    if (T.length != F.length) {
      return ValidationResult.error(
        'Длина T (${T.length}) не совпадает с длиной F (${F.length})'
      );
    }
    
    if (L.length != F.length - 1) {
      return ValidationResult.error(
        'Длина L (${L.length}) должна быть ${F.length - 1}, а не ${L.length}'
      );
    }
    
    // Проверка допустимых типов
    for (int i = 0; i < T.length; i++) {
      if (!DrainageTypes.validTypes.contains(T[i])) {
        return ValidationResult.error(
          'Неизвестный тип лотка на позиции $i: "${T[i]}". '
          'Допустимые: ${DrainageTypes.validTypes.join(", ")}'
        );
      }
    }
    
    // Проверка последовательностей
    for (int i = 0; i < T.length - 1; i++) {
      if (T[i] == 'PR' && T[i + 1] == 'PR') {
        return ValidationResult.error(
          'Недопустимо два PR подряд на позициях $i и ${i + 1}'
        );
      }
      if (T[i] == 'DK' && T[i + 1] == 'DK') {
        return ValidationResult.error(
          'Недопустимо два DK подряд на позициях $i и ${i + 1}'
        );
      }
    }
    
    // Проверка количества водоразделов
    int vCount = T.where((t) => t == 'V').length;
    if (vCount > 1) {
      return ValidationResult.error(
        'Водораздел "V" должен быть только один или отсутствовать'
      );
    }
    
    // Проверка минимального количества не-PR лотков
    int nonPrCount = T.where((t) => t != 'PR').length;
    if (nonPrCount < 2) {
      return ValidationResult.error(
        'В системе должно быть минимум 2 не-PR лотка'
      );
    }
    
    return ValidationResult.ok();
  }
}
