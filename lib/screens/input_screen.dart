import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:drainage_app/services/drainage_core.dart';
import 'package:drainage_app/repositories/repository_factory.dart';
import 'package:drainage_app/repositories/data_repository.dart';
import 'package:drainage_app/screens/result_screen.dart';
import 'package:drainage_app/screens/settings_screen.dart';
import 'package:drainage_app/screens/projects_list_screen.dart';
import 'dart:convert';

class InputScreen extends StatefulWidget {
  final int? projectId;
  final int? sectionNumber;
  final Map<String, dynamic>? projectSettings;
  
  const InputScreen({
    super.key,
    this.projectId,
    this.sectionNumber,
    this.projectSettings,
  });

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final List<PointData> points = [
    PointData(f: 0, type: 'PR', length: 0),
    PointData(f: 0, type: 'O', length: 0),
    PointData(f: 0, type: 'V', length: 0),
  ];

  // Контроллеры предотвращают потерю данных при прокрутке ListView
  final List<TextEditingController> _fControllers = [];
  final List<TextEditingController> _lControllers = [];
  
  bool isCalculating = false;
  
  double kMin = DrainageTypes.kMin;
  int delta = DrainageTypes.delta;
  double desiredLayer = DrainageTypes.defaultDesiredLayer;
  bool useH2 = DrainageTypes.defaultUseH2;
  bool useH3 = true;
  bool compareAllMethods = false;
  Map<String, List<int>> tolerance = Map.from(DrainageTypes.tolerance);

  // F/P — отсчёты по рейке, хранятся в points[i].f всегда в мм.
  // useMeters — только формат ввода/отображения (мм ↔ м), на расчёт не влияет.
  bool useMeters = false;

  // Режим ввода отметок — фундаментальный выбор на весь проект (для
  // быстрого расчёта — обычный тумблер здесь же). 'rod' — как обычно
  // (отсчёт по рейке), 'absolute' — абсолютные отметки через искусственный
  // горизонт (ГИ). giMode: 'auto' (фиксируется по первому сохранённому
  // участку) | 'manual' (задан при создании проекта). gi — сам горизонт,
  // в мм; null, пока не зафиксирован (auto, участков ещё не было).
  String elevationMode = 'rod';
  String giMode = 'auto';
  double? gi;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.projectSettings != null) {
      kMin = (widget.projectSettings!['kMin'] as num?)?.toDouble() ?? DrainageTypes.kMin;
      delta = (widget.projectSettings!['delta'] as num?)?.toInt() ?? DrainageTypes.delta;
      desiredLayer = (widget.projectSettings!['desiredLayer'] as num?)?.toDouble() ?? DrainageTypes.defaultDesiredLayer;
      useH2 = widget.projectSettings!['useH2'] as bool? ?? DrainageTypes.defaultUseH2;
      useH3 = widget.projectSettings!['useH3'] as bool? ?? true;
      compareAllMethods = widget.projectSettings!['compareAllMethods'] as bool? ?? false;
      useMeters = widget.projectSettings!['useMeters'] as bool? ?? false;
      elevationMode = widget.projectSettings!['elevationMode'] as String? ?? 'rod';
      giMode = widget.projectSettings!['giMode'] as String? ?? 'auto';
      gi = (widget.projectSettings!['gi'] as num?)?.toDouble();
      if (widget.projectSettings!['tolerance'] != null) {
        tolerance = Map<String, List<int>>.from(
          (widget.projectSettings!['tolerance'] as Map).map(
            (key, value) => MapEntry(
              key.toString(),
              (value as List).map((e) => (e as num).toInt()).toList(),
            ),
          ),
        );
      }
    }
    
    _syncControllers();
  }

  void _syncControllers() {
    while (_fControllers.length < points.length) {
      final i = _fControllers.length;
      _fControllers.add(TextEditingController(text: _fDisplayText(points[i].f)));
    }
    while (_lControllers.length < points.length) {
      final i = _lControllers.length;
      _lControllers.add(TextEditingController(
        text: points[i].length == 0 ? '' : points[i].length.toString(),
      ));
    }
    while (_fControllers.length > points.length) {
      _fControllers.removeLast().dispose();
    }
    while (_lControllers.length > points.length) {
      _lControllers.removeLast().dispose();
    }
  }

  /// Текст для поля F с учётом текущего режима:
  /// - режим "абсолютные отметки": хранится и показывается как есть (то,
  ///   что ввели) — конвертация в отсчёт по рейке происходит только в
  ///   момент расчёта, через горизонт (ГИ).
  /// - обычный режим: мм целыми, или м с тремя знаками (useMeters).
  String _fDisplayText(double rawValue) {
    if (rawValue == 0) return '';
    if (elevationMode == 'absolute') return rawValue.toString();
    return useMeters ? (rawValue / 1000).toString() : rawValue.toString();
  }

  /// Перерисовать текст во всех полях F под текущий useMeters — нужно
  /// вызывать сразу после переключения формата через шестерёнку, иначе
  /// уже введённые значения останутся показаны в старом формате.
  void _refreshFieldTextForUnits() {
    for (int i = 0; i < points.length; i++) {
      _fControllers[i].text = _fDisplayText(points[i].f);
    }
  }

  @override
  void dispose() {
    for (final c in _fControllers) c.dispose();
    for (final c in _lControllers) c.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final String title = widget.projectId != null 
        ? 'Участок ${widget.sectionNumber}'
        : 'Расчёт продольного профиля';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.projectId == null)
            IconButton(
              icon: const Icon(Icons.folder),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProjectsListScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final settings = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              if (settings != null) {
                final bool oldUseMeters = useMeters;
                setState(() {
                  kMin = settings['kMin'] ?? DrainageTypes.kMin;
                  delta = settings['delta'] ?? DrainageTypes.delta;
                  desiredLayer = settings['desiredLayer'] ?? DrainageTypes.defaultDesiredLayer;
                  useH2 = settings['useH2'] ?? DrainageTypes.defaultUseH2;
                  useH3 = settings['useH3'] ?? true;
                  compareAllMethods = settings['compareAllMethods'] ?? false;
                  useMeters = settings['useMeters'] ?? false;
                  if (settings['tolerance'] != null) {
                    tolerance = Map<String, List<int>>.from(settings['tolerance']);
                  }
                });
                if (useMeters != oldUseMeters) {
                  _refreshFieldTextForUnits();
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: const Text(
              'ВВОД ДАННЫХ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          
          if (widget.projectId == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Абсолютные отметки'),
                value: elevationMode == 'absolute',
                onChanged: (value) => setState(() {
                  elevationMode = value ? 'absolute' : 'rod';
                  giMode = 'auto';
                  gi = null;
                  _refreshFieldTextForUnits();
                }),
              ),
            ),

          if (widget.projectSettings != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Настройки проекта применены:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'K_min: ${kMin.toStringAsFixed(1)} мм/м • Delta: $delta мм • Слой: ${desiredLayer.toStringAsFixed(0)} мм'
                    '${useMeters ? " • Ввод в метрах" : ""}'
                    '${elevationMode == 'absolute' ? " • Абсолютные отметки (${giMode == 'auto' ? 'ГИ авто' : 'ГИ вручную'})" : ""}',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                  ),
                ],
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const SizedBox(width: 30, child: Text('№', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: Text(elevationMode == 'absolute' ? 'Абс. отметка, м' : 'Отметка (F)${useMeters ? ", м" : ""}', style: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                const Expanded(flex: 2, child: Text('Тип', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                const Expanded(flex: 2, child: Text('Расстояние (L)', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: 48),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              itemCount: points.length,
              itemBuilder: (context, index) => _buildPointRow(index),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addPoint,
                icon: const Icon(Icons.add),
                label: const Text('Добавить точку'),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.refresh),
                label: const Text('СБРОСИТЬ'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isCalculating ? null : _calculate,
                icon: isCalculating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.calculate),
                label: Text(isCalculating ? 'РАСЧЁТ...' : 'РАССЧИТАТЬ'),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPointRow(int index) {
    final point = points[index];
    final isLast = index == points.length - 1;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(width: 30, child: Text('$index', style: const TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            
            Expanded(
              flex: 2,
              child: TextField(
                controller: _fControllers[index],
                decoration: InputDecoration(
                  hintText: elevationMode == 'absolute'
                      ? 'Абс. отметка, м'
                      : (useMeters ? 'F, м' : 'F'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  final raw = double.tryParse(value) ?? 0;
                  if (elevationMode == 'absolute') {
                    // Храним как ввели (абсолютная отметка, м) — перевод в
                    // отсчёт по рейке (через ГИ) происходит одним разом в
                    // момент расчёта, не по мере ввода: ГИ в auto-режиме
                    // зависит от максимума среди ВСЕХ точек участка, и
                    // пересчитывать уже введённые точки на лету при вводе
                    // следующей было бы плывущей целью.
                    point.f = raw;
                  } else {
                    point.f = useMeters ? raw * 1000 : raw;
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: point.type,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: DrainageTypes.validTypes
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) => setState(() => point.type = value ?? 'O'),
              ),
            ),
            const SizedBox(width: 8),
            
            if (!isLast)
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _lControllers[index],
                  decoration: const InputDecoration(
                    hintText: 'L',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) => point.length = double.tryParse(value) ?? 0,
                ),
              )
            else
              const Expanded(flex: 2, child: SizedBox()),
            
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: points.length > 3 ? () => _removePoint(index) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
  
  void _addPoint() {
    setState(() {
      points.add(PointData(f: 0, type: 'O', length: 0));
      _syncControllers();
    });
  }
  
  void _removePoint(int index) {
    if (points.length > 3) {
      setState(() {
        points.removeAt(index);
        _fControllers.removeAt(index).dispose();
        _lControllers.removeAt(index).dispose();
      });
    }
  }
  
  void _resetForm() {
    for (final c in _fControllers) c.dispose();
    for (final c in _lControllers) c.dispose();
    _fControllers.clear();
    _lControllers.clear();
    
    setState(() {
      points.clear();
      points.addAll([
        PointData(f: 0, type: 'PR', length: 0),
        PointData(f: 0, type: 'O', length: 0),
        PointData(f: 0, type: 'V', length: 0),
      ]);
      desiredLayer = DrainageTypes.defaultDesiredLayer;
      useH2 = DrainageTypes.defaultUseH2;
      _syncControllers();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Форма сброшена'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  Future<void> _calculate() async {
    setState(() => isCalculating = true);
    
    try {
      // В режиме абсолютных отметок сначала переводим введённые значения
      // в отсчёт по рейке через горизонт (ГИ) — одним разом для всех точек
      // сразу, а не по мере ввода: в auto-режиме ГИ зависит от максимума
      // среди ВСЕХ точек участка, пересчитывать уже введённые точки на
      // лету было бы плывущей целью.
      List<double> effectiveF;
      double? freshlyComputedGi; // если auto и ГИ ещё не был зафиксирован

      if (elevationMode == 'absolute') {
        double giMm;
        if (gi != null) {
          giMm = gi!;
        } else {
          final maxAbsMeters = points.map((p) => p.f).reduce((a, b) => a > b ? a : b);
          final giMeters = ((maxAbsMeters / 100).ceil() * 100) + 100;
          giMm = giMeters * 1000.0;
          if (giMode == 'auto') {
            freshlyComputedGi = giMm; // зафиксируем после успешного сохранения
          }
        }
        effectiveF = points.map((p) => giMm - (p.f * 1000.0)).toList();
      } else {
        effectiveF = points.map((p) => p.f).toList();
      }

      final pointsJson = points.asMap().map((i, p) => MapEntry(i, {
        'f': effectiveF[i],
        'type': p.type,
        'length': i < points.length - 1 ? p.length : 0,
      })).values.toList();
      
      // compute() запускает расчёт в отдельном isolate — интерфейс
      // остаётся отзывчивым (спиннер реально крутится), приложение не
      // виснет на профилях с 10+ точками.
      final resultJson = await compute(calculateDrainageIsolate, {
        'pointsJson': jsonEncode(pointsJson),
        'useH2': useH2,
        'desiredLayer': desiredLayer,
        'kMin': kMin,
        'delta': delta,
        'useH3': useH3,
        'compareAllMethods': compareAllMethods,
        'tolerance': tolerance,
      });
      
      if (widget.projectId != null && widget.sectionNumber != null) {
        await _saveSectionWithResult(
          resultJson,
          effectiveF: effectiveF,
          freshlyComputedGi: freshlyComputedGi,
        );

        // Настройки проекта для передачи дальше (следующий участок из
        // экрана результата) — с только что зафиксированным ГИ, если он
        // был вычислен впервые в этом расчёте. widget.projectSettings сам
        // по себе не обновится (это тот снимок, что был при открытии этого
        // экрана), поэтому мёрджим свежий gi поверх копии.
        final forwardedProjectSettings = Map<String, dynamic>.from(widget.projectSettings ?? {});
        if (freshlyComputedGi != null) {
          forwardedProjectSettings['gi'] = freshlyComputedGi;
        }
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                resultJson: resultJson,
                projectId: widget.projectId,
                currentSectionNumber: widget.sectionNumber,
                projectSettings: forwardedProjectSettings,
                useMeters: useMeters,
                elevationMode: elevationMode,
                giMode: giMode,
                gi: gi ?? freshlyComputedGi,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                resultJson: resultJson,
                useMeters: useMeters,
                elevationMode: elevationMode,
                giMode: giMode,
                gi: gi ?? freshlyComputedGi,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => isCalculating = false);
    }
  }
  
  Future<void> _saveSectionWithResult(
    String resultJson, {
    required List<double> effectiveF,
    double? freshlyComputedGi,
  }) async {
    try {
      final inputData = {
        // F хранится в канонической форме — отсчёт по рейке (мм), как и
        // везде в приложении (совместимо с уже существующим анализом
        // сезона). Если вводили абсолютные отметки — они сохраняются
        // отдельно, для истории/сверки, а не вместо F.
        'F': effectiveF,
        'T': points.map((p) => p.type).toList(),
        'L': points.map((p) => p.length).toList(),
        if (elevationMode == 'absolute')
          'absoluteInputMeters': points.map((p) => p.f).toList(),
      };

      // Снимок настроек, реально использованных для ЭТОГО расчёта — чтобы
      // при анализе за сезон не пришлось восстанавливать их обратным
      // счётом (desiredLayer) или гадать вовсе (kMin/tolerance), как в
      // прошлый раз.
      final settingsSnapshot = {
        'kMin': kMin,
        'delta': delta,
        'desiredLayer': desiredLayer,
        'useH2': useH2,
        'useH3': useH3,
        'compareAllMethods': compareAllMethods,
        'tolerance': tolerance,
        'useMeters': useMeters,
        'elevationMode': elevationMode,
        'giMode': giMode,
        'gi': gi ?? freshlyComputedGi,
      };
      
      final DataRepository db = RepositoryFactory.instance;

      // Если ГИ только что вычислен впервые (auto, ещё не был зафиксирован) —
      // фиксируем его в настройках проекта, чтобы следующие участки этого
      // же проекта использовали то же самое число, без пересчёта задним
      // числом.
      if (freshlyComputedGi != null) {
        final updatedProjectSettings = Map<String, dynamic>.from(widget.projectSettings ?? {});
        updatedProjectSettings['gi'] = freshlyComputedGi;
        await db.updateProject(id: widget.projectId!, settings: jsonEncode(updatedProjectSettings));
        gi = freshlyComputedGi; // на случай повторного расчёта в этой же сессии
      }

      final sections = await db.getProjectSections(widget.projectId!);
      final existingSection = sections.where(
        (s) => s['section_number'] == widget.sectionNumber,
      ).toList();
      
      final resultMap = jsonDecode(resultJson) as Map<String, dynamic>;
      
      if (existingSection.isNotEmpty) {
        await db.updateSection(
          id: existingSection.first['id'],
          inputData: jsonEncode(inputData),
          resultData: jsonEncode(resultMap),
          settingsSnapshot: jsonEncode(settingsSnapshot),
        );
      } else {
        await db.addSection(
          projectId: widget.projectId!,
          sectionNumber: widget.sectionNumber!,
          inputData: inputData,
          resultData: resultMap,
          settingsSnapshot: settingsSnapshot,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Участок сохранён'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Раньше это была тихая потеря результата (только print(), без
      // видимого следа для пользователя) — теперь показываем явную ошибку,
      // чтобы не выглядело так, будто участок сохранился, когда на самом
      // деле нет.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось сохранить участок: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class PointData {
  double f;
  String type;
  double length;
  
  PointData({required this.f, required this.type, required this.length});
}
