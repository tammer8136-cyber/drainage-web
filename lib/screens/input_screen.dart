import 'package:flutter/material.dart';
import 'package:drainage_app/services/drainage_core.dart';
import 'package:drainage_app/screens/result_screen.dart';
import 'package:drainage_app/screens/settings_screen.dart';
import 'package:drainage_app/screens/projects_list_screen.dart';
import 'package:drainage_app/repositories/repository_factory.dart';
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
  
  bool isCalculating = false;
  
  // Настройки (могут быть из проекта или дефолтные)
  double kMin = DrainageTypes.kMin;
  int delta = DrainageTypes.delta;
  double desiredLayer = DrainageTypes.defaultDesiredLayer;
  bool useH2 = true;
  bool useH3 = true;
  bool compareAllMethods = false;
  Map<String, List<int>> tolerance = Map.from(DrainageTypes.tolerance);
  
  // Ключ для принудительного пересоздания формы
  Key _formKey = UniqueKey();
  
  @override
  void initState() {
    super.initState();
    
    // Загружаем настройки проекта если есть
    if (widget.projectSettings != null) {
      kMin = (widget.projectSettings!['kMin'] as num?)?.toDouble() ?? DrainageTypes.kMin;
      delta = (widget.projectSettings!['delta'] as num?)?.toInt() ?? DrainageTypes.delta;
      desiredLayer = (widget.projectSettings!['desiredLayer'] as num?)?.toDouble() ?? DrainageTypes.defaultDesiredLayer;
      useH2 = widget.projectSettings!['useH2'] as bool? ?? true;
      useH3 = widget.projectSettings!['useH3'] as bool? ?? true;
      compareAllMethods = widget.projectSettings!['compareAllMethods'] as bool? ?? false;
      
      // Загружаем допуски если есть
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
          // Кнопка проектов (только если не в режиме добавления участка)
          if (widget.projectId == null)
            IconButton(
              icon: const Icon(Icons.folder),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProjectsListScreen()),
                );
              },
            ),
          // Настройки (можно переопределить настройки проекта)
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final settings = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              if (settings != null) {
                setState(() {
                  kMin = settings['kMin'] ?? DrainageTypes.kMin;
                  delta = settings['delta'] ?? DrainageTypes.delta;
                  desiredLayer = settings['desiredLayer'] ?? DrainageTypes.defaultDesiredLayer;
                  useH2 = settings['useH2'] ?? true;
                  useH3 = settings['useH3'] ?? true;
                  compareAllMethods = settings['compareAllMethods'] ?? false;
                  if (settings['tolerance'] != null) {
                    tolerance = Map<String, List<int>>.from(settings['tolerance']);
                  }
                });
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
          
          // Панель текущих настроек
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
                    'K_min: ${kMin.toStringAsFixed(1)} мм/м • Delta: $delta мм • Слой: ${desiredLayer.toStringAsFixed(0)} мм',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                  ),
                ],
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: const [
                SizedBox(width: 30, child: Text('№', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Отметка (F)', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Тип', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Расстояние (L)', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 48),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              key: _formKey,  // Ключ для пересоздания
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
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
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
                decoration: const InputDecoration(hintText: 'F', isDense: true, border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => setState(() => point.f = double.tryParse(value) ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: point.type,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                items: DrainageTypes.validTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) => setState(() => point.type = value ?? 'O'),
              ),
            ),
            const SizedBox(width: 8),
            
            if (!isLast)
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: const InputDecoration(hintText: 'L', isDense: true, border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) => setState(() => point.length = double.tryParse(value) ?? 0),
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
  
  void _addPoint() => setState(() => points.add(PointData(f: 0, type: 'O', length: 0)));
  
  void _removePoint(int index) {
    if (points.length > 3) setState(() => points.removeAt(index));
  }
  
  void _resetForm() {
    setState(() {
      // Сброс к начальному состоянию
      points.clear();
      points.addAll([
        PointData(f: 0, type: 'PR', length: 0),
        PointData(f: 0, type: 'O', length: 0),
        PointData(f: 0, type: 'V', length: 0),
      ]);
      desiredLayer = 50.0;
      useH2 = true;
      
      // Генерируем новый ключ чтобы пересоздать форму
      _formKey = UniqueKey();
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
      final pointsJson = points.asMap().map((i, p) => MapEntry(i, {
        'f': p.f,
        'type': p.type,
        'length': i < points.length - 1 ? p.length : 0,
      })).values.toList();
      
      final resultJson = await calculateDrainageAction(
        jsonEncode(pointsJson),
        useH2,
        desiredLayer,
        kMin: kMin,
        delta: delta,
        useH3: useH3,
        compareAllMethods: compareAllMethods,
        tolerance: tolerance,
      );
      
      // Если это часть проекта, сохраняем участок перед показом результата
      if (widget.projectId != null && widget.sectionNumber != null) {
        await _saveSectionWithResult(resultJson);
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                resultJson: resultJson,
                projectId: widget.projectId,
                currentSectionNumber: widget.sectionNumber,
                projectSettings: widget.projectSettings,
              ),
            ),
          );
        }
      } else {
        // Обычный расчёт - показываем результат
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ResultScreen(resultJson: resultJson)),
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
  
  // Сохранить участок с результатами расчёта
  Future<void> _saveSectionWithResult(String resultJson) async {
    try {
      // Подготавливаем входные данные
      final inputData = {
        'F': points.map((p) => p.f).toList(),
        'T': points.map((p) => p.type).toList(),
        'L': points.map((p) => p.length).toList(),
      };
      
      // Получаем репозиторий
      final repo = await RepositoryFactory.getInstance();
      
      // Проверяем существует ли уже такой участок
      final sections = await repo.getSections(widget.projectId!);
      final existingSection = sections.where(
        (s) => s['section_number'] == widget.sectionNumber
      ).toList();
      
      if (existingSection.isNotEmpty) {
        // Обновляем существующий участок
        await repo.updateSection(
          id: existingSection.first['id'],
          inputData: jsonEncode(inputData),
          resultData: resultJson,
        );
      } else {
        // Создаём новый участок
        await repo.insertSection(
          projectId: widget.projectId!,
          sectionNumber: widget.sectionNumber!,
          name: 'Участок ${widget.sectionNumber}',
          inputData: jsonEncode(inputData),
          resultData: resultJson,
        );
      }
      
      // Показываем уведомление
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
      // Логируем ошибку, но не блокируем переход на результат
      print('Error saving section: $e');
    }
  }
}

class PointData {
  double f;
  String type;
  double length;
  
  PointData({required this.f, required this.type, required this.length});
}
