/// Модуль drainage_core - Главный решатель
/// Часть системы расчёта дренажного профиля

import 'models/input.dart';
import 'models/result.dart';
import 'models/settings.dart';
import 'models/validation.dart';
import 'algorithms/solver_base.dart';
import 'algorithms/h0_solver.dart';
import 'algorithms/h2_solver.dart';
import 'algorithms/h3_solver.dart';
import 'optimization/optimizer.dart';

/// Главный класс для расчёта дренажа
class DrainageSolver {
  /// Решить дренажную систему
  /// 
  /// Параметры:
  /// - [F] - отметки поверхности (мм)
  /// - [T] - типы лотков
  /// - [L] - длины сегментов (м)
  /// - [refineWatershed] - использовать H2 (плавающий водораздел)
  /// - [debug] - режим отладки
  /// - [desiredLayer] - желаемый слой асфальта
  /// - [settings] - настройки расчёта
  static Future<DrainageResult> solve({
    required List<double> F,
    required List<String> T,
    required List<double> L,
    bool refineWatershed = false,
    bool debug = false,
    double? desiredLayer,
    DrainageSettings? settings,
  }) async {
    final startTime = DateTime.now();
    
    // Использовать переданные настройки или создать по умолчанию
    final DrainageSettings activeSettings = settings ?? DrainageSettings.defaults();
    
    // Если desiredLayer передан напрямую, использовать его
    if (desiredLayer != null) {
      activeSettings.desiredLayer = desiredLayer;
    }
    
    // Валидация настроек
    final settingsError = activeSettings.validate();
    if (settingsError != null) {
      return DrainageResult.error(
        error: 'Ошибка настроек: $settingsError',
        computationTime: elapsedSeconds(startTime),
      );
    }
    
    // Валидация входных данных
    final input = DrainageInput(F: F, T: T, L: L);
    final validation = DrainageValidation.validate(input);
    
    if (!validation.isValid) {
      return DrainageResult.error(
        error: validation.message,
        computationTime: elapsedSeconds(startTime),
      );
    }
    
    final bool hasFixedV = T.contains('V') || T.contains('VK');
    
    // Генерация P_set
    final List<List<double>> pSet = generatePSet(F, T, activeSettings);
    
    if (debug) {
      print('P_set generated: ${pSet.map((p) => p.length).toList()}');
    }
    
    // Поиск решений
    List<Solution> solutions = [];

    if (activeSettings.compareAllMethods && refineWatershed) {
      // Честное сравнение: собираем кандидатов ОБОИХ применимых алгоритмов
      // в один список и передаём разом в оптимизатор — он и так уже выбирает
      // лучшее по score из любого переданного списка. H3 участвует в
      // сравнении, только если в профиле нет явной V/VK (иначе H3
      // проигнорировал бы смысл этой метки, проведя прямую линию через
      // низшую точку вместо честного водораздела).
      if (hasFixedV) {
        // H0 (водораздел зафиксирован на V/VK) против H2 (свободный)
        final h0Solutions = H0Solver.solveH0(
          F: F, T: T, L: L, pSet: pSet, settings: activeSettings, debug: debug,
        );
        final h2Solutions = H2Solver.solveH2(
          F: F, T: T, L: L, pSet: pSet, settings: activeSettings, debug: debug,
        );
        solutions = [...h0Solutions, ...h2Solutions];

        if (debug) {
          print('Сравнение H0 (${h0Solutions.length}) vs H2 (${h2Solutions.length})');
        }
      } else {
        // H2 против H3 (H3 — только если включён и применим)
        final h2Solutions = H2Solver.solveH2(
          F: F, T: T, L: L, pSet: pSet, settings: activeSettings, debug: debug,
        );
        List<Solution> h3Solutions = [];
        if (activeSettings.useH3 &&
            H3Solver.canApplyH3(F: F, T: T, L: L, settings: activeSettings)) {
          h3Solutions = H3Solver.solveH3(
            F: F, T: T, L: L, pSet: pSet, settings: activeSettings, debug: debug,
          );
        }
        solutions = [...h2Solutions, ...h3Solutions];

        if (debug) {
          print('Сравнение H2 (${h2Solutions.length}) vs H3 (${h3Solutions.length})');
        }
      }
    } else {
      // Обычная цепочка с ранним выходом (без сравнения)

      // H0: Фиксированный водораздел
      if (hasFixedV) {
        solutions = H0Solver.solveH0(
          F: F,
          T: T,
          L: L,
          pSet: pSet,
          settings: activeSettings,
          debug: debug,
        );

        if (debug) {
          print('H0 found ${solutions.length} solutions');
        }
      }

      // H2: Плавающий водораздел (если H0 не нашёл решений)
      if ((!hasFixedV || solutions.isEmpty) && refineWatershed) {
        solutions = H2Solver.solveH2(
          F: F,
          T: T,
          L: L,
          pSet: pSet,
          settings: activeSettings,
          debug: debug,
        );

        if (debug) {
          print('H2 found ${solutions.length} solutions');
        }
      }

      // H3: Прямой уклон (если H2 не нашёл решений и H3 применим)
      if (solutions.isEmpty &&
          activeSettings.useH3 &&
          H3Solver.canApplyH3(F: F, T: T, L: L, settings: activeSettings)) {
        if (debug) {
          print('Trying H3 (direct slope)...');
        }

        solutions = H3Solver.solveH3(
          F: F,
          T: T,
          L: L,
          pSet: pSet,
          settings: activeSettings,
          debug: debug,
        );

        if (debug) {
          print('H3 found ${solutions.length} solutions');
        }
      }
    }
    
    // Если нет решений
    if (solutions.isEmpty) {
      return DrainageResult.error(
        error: 'Система нерешаема',
        computationTime: elapsedSeconds(startTime),
      );
    }
    
    // Оптимизация - выбор лучшего решения
    final best = DrainageOptimizer.optimizeSolution(
      solutions: solutions,
      F: F,
      T: T,
      L: L,
      desiredLayer: activeSettings.desiredLayer,
    );
    
    return DrainageResult.success(
      solution: best.P,
      vIndex: best.vIndex,
      score: best.score,
      averageLayer: best.averageLayer,
      totalSolutions: solutions.length,
      computationTime: elapsedSeconds(startTime),
      F: best.F,
      T: best.T,
      L: best.L,
      metadata: best.metadata,
    );
  }
}
