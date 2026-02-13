import 'package:flutter/material.dart';
import 'package:drainage_app/services/drainage_core.dart';
import 'package:drainage_app/services/settings_service.dart';

class ProjectSettingsScreen extends StatefulWidget {
  final int projectId;
  final Map<String, dynamic>? currentSettings;
  
  const ProjectSettingsScreen({
    super.key,
    required this.projectId,
    this.currentSettings,
  });

  @override
  State<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends State<ProjectSettingsScreen> {
  late double kMin;
  late int delta;
  late double desiredLayer;
  late bool useH2;
  late bool useH3;
  late bool compareAllMethods;
  
  // Допуски (копия для редактирования)
  late Map<String, List<int>> tolerance;
  
  // Контроллеры для полей допусков
  final Map<String, List<TextEditingController>> _toleranceControllers = {};

  @override
  void initState() {
    super.initState();
    
    // Загружаем текущие настройки проекта или дефолтные
    if (widget.currentSettings != null) {
      kMin = (widget.currentSettings!['kMin'] as num?)?.toDouble() ?? DrainageTypes.kMin;
      delta = (widget.currentSettings!['delta'] as num?)?.toInt() ?? DrainageTypes.delta;
      desiredLayer = (widget.currentSettings!['desiredLayer'] as num?)?.toDouble() ?? DrainageTypes.defaultDesiredLayer;
      useH2 = widget.currentSettings!['useH2'] as bool? ?? true;
      useH3 = widget.currentSettings!['useH3'] as bool? ?? true;
      compareAllMethods = widget.currentSettings!['compareAllMethods'] as bool? ?? false;
      
      // Загружаем допуски если есть
      if (widget.currentSettings!['tolerance'] != null) {
        tolerance = Map<String, List<int>>.from(
          (widget.currentSettings!['tolerance'] as Map).map(
            (key, value) => MapEntry(
              key.toString(),
              (value as List).map((e) => (e as num).toInt()).toList(),
            ),
          ),
        );
      } else {
        tolerance = Map.from(DrainageTypes.tolerance);
      }
    } else {
      // Дефолтные значения
      kMin = DrainageTypes.kMin;
      delta = DrainageTypes.delta;
      desiredLayer = DrainageTypes.defaultDesiredLayer;
      useH2 = true;
      useH3 = true;
      compareAllMethods = false;
      tolerance = Map.from(DrainageTypes.tolerance);
    }
    
    // Инициализируем контроллеры
    _initToleranceControllers();
  }
  
  @override
  void dispose() {
    // Очищаем контроллеры
    for (final controllers in _toleranceControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }
  
  void _initToleranceControllers() {
    // Создаём контроллеры для всех допусков
    for (final entry in tolerance.entries) {
      _toleranceControllers[entry.key] = [
        TextEditingController(text: entry.value[0].toString()),
        TextEditingController(text: entry.value[1].toString()),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки проекта'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Пояснение
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Эти настройки будут применяться ко всем участкам проекта',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          // K_min
          _buildParameterCard(
            'K_min (минимальный уклон, мм/м)',
            kMin,
            min: 2.0,
            max: 5.0,
            divisions: 30,
            onChanged: (value) => setState(() => kMin = value),
          ),
          
          const SizedBox(height: 16),
          
          // Delta
          _buildIntParameterCard(
            'Delta (шаг генерации, мм)',
            delta,
            min: 1,
            max: 10,
            onChanged: (value) => setState(() => delta = value.round()),
          ),
          
          const SizedBox(height: 16),
          
          // Желаемый слой
          _buildParameterCard(
            'Желаемый слой (мм)',
            desiredLayer,
            min: 30.0,
            max: 210.0,
            divisions: 180,
            onChanged: (value) => setState(() => desiredLayer = value),
          ),
          
          const SizedBox(height: 16),
          
          // Использовать H2
          Card(
            child: SwitchListTile(
              title: const Text('Использовать плавающий водораздел (H2)'),
              subtitle: const Text('Если не найдено решений с фиксированным V, попробовать виртуальный водораздел'),
              value: useH2,
              onChanged: (value) => setState(() => useH2 = value),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Использовать H3
          Card(
            child: SwitchListTile(
              title: const Text('Использовать прямой уклон (H3)'),
              subtitle: const Text('Для монотонных профилей без естественных водоразделов'),
              value: useH3,
              onChanged: (value) => setState(() => useH3 = value),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Сравнение всех методов
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Сравнение всех методов'),
                  subtitle: const Text('Находит лучшее решение среди всех алгоритмов'),
                  value: compareAllMethods,
                  onChanged: (value) => setState(() => compareAllMethods = value),
                ),
                if (compareAllMethods)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: const [
                        Icon(Icons.speed, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Расчёт может занять больше времени, но результат будет точнее',
                            style: TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Допуски по типам точек
          const Text(
            'ДОПУСКИ ПО ТИПАМ ТОЧЕК',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Таблица допусков
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Заголовок
                  Row(
                    children: const [
                      Expanded(flex: 2, child: Text('Тип', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('Min (мм)', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('Max (мм)', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const Divider(),
                  
                  // Строки для каждого типа
                  ...[
                    _buildToleranceRow('PR', 'Примыкание'),
                    _buildToleranceRow('P', 'Пешеходное'),
                    _buildToleranceRow('O', 'Обычная'),
                    _buildToleranceRow('V', 'Водораздел'),
                    _buildToleranceRow('DK', 'Дождевой колодец'),
                    _buildToleranceRow('K', 'Карта'),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Кнопки
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetDefaults,
                  child: const Text('СБРОСИТЬ'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Text('СОХРАНИТЬ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Карточка параметра с слайдером
  Widget _buildParameterCard(
    String label,
    double value, {
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    label: value.toStringAsFixed(1),
                    onChanged: onChanged,
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Карточка целочисленного параметра
  Widget _buildIntParameterCard(
    String label,
    int value, {
    required int min,
    required int max,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: value.toDouble(),
                    min: min.toDouble(),
                    max: max.toDouble(),
                    divisions: max - min,
                    label: value.toString(),
                    onChanged: onChanged,
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Строка допуска
  Widget _buildToleranceRow(String type, String description) {
    final values = tolerance[type]!;
    
    // Создаём контроллеры если их нет
    if (!_toleranceControllers.containsKey(type)) {
      _toleranceControllers[type] = [
        TextEditingController(text: values[0].toString()),
        TextEditingController(text: values[1].toString()),
      ];
    }
    
    final controllers = _toleranceControllers[type]!;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: controllers[0], // Используем контроллер
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  tolerance[type]![0] = parsed;
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: controllers[1], // Используем контроллер
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  tolerance[type]![1] = parsed;
                }
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // Сбросить значения по умолчанию
  void _resetDefaults() {
    setState(() {
      kMin = DrainageTypes.kMin;
      delta = DrainageTypes.delta;
      desiredLayer = DrainageTypes.defaultDesiredLayer;
      useH2 = true;
      useH3 = true;
      compareAllMethods = false;
      
      // Deep copy допусков
      tolerance = Map<String, List<int>>.from(
        DrainageTypes.tolerance.map(
          (key, value) => MapEntry(key, List<int>.from(value)),
        ),
      );
      
      // Обновляем контроллеры с новыми значениями
      for (final entry in tolerance.entries) {
        if (_toleranceControllers.containsKey(entry.key)) {
          _toleranceControllers[entry.key]![0].text = entry.value[0].toString();
          _toleranceControllers[entry.key]![1].text = entry.value[1].toString();
        }
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки сброшены')),
    );
  }
  
  // Сохранить настройки
  Future<void> _saveSettings() async {
    // Валидация
    for (var entry in tolerance.entries) {
      if (entry.value[0] > entry.value[1]) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: Для типа ${entry.key} минимум больше максимума'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    // Сохраняем настройки проекта также в глобальные настройки (SharedPreferences)
    await SettingsService.saveSettings(
      kMin: kMin,
      delta: delta,
      desiredLayer: desiredLayer,
      useH2: useH2,
      useH3: useH3,
      compareAllMethods: compareAllMethods,
      tolerance: tolerance,
    );
    
    // Возвращаем настройки
    if (!mounted) return;
    Navigator.pop(context, {
      'kMin': kMin,
      'delta': delta,
      'desiredLayer': desiredLayer,
      'useH2': useH2,
      'useH3': useH3,
      'compareAllMethods': compareAllMethods,
      'tolerance': tolerance,
    });
  }
}
