import 'package:flutter/material.dart';
import 'package:drainage_app/services/export_service.dart';
import '../repositories/repository_factory.dart';
import '../repositories/data_repository.dart';
import 'input_screen.dart';
import 'dart:convert';

/// Экран результата с прокруткой и стрелками уклонов
class ResultScreen extends StatefulWidget {
  final String resultJson;
  final int? projectId;
  final int? currentSectionNumber;
  final Map<String, dynamic>? projectSettings;
  
  const ResultScreen({
    super.key,
    required this.resultJson,
    this.projectId,
    this.currentSectionNumber,
    this.projectSettings,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  DataRepository? _repo;
  
  @override
  void initState() {
    super.initState();
    _initRepository();
  }
  
  Future<void> _initRepository() async {
    _repo = await RepositoryFactory.getInstance();
  }
  
  @override
  Widget build(BuildContext context) {
    final result = jsonDecode(widget.resultJson);
    final bool isSolvable = result['status'] == 'РЕШАЕМО';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Результат'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              // Возвращаемся на главный экран (список проектов)
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            tooltip: 'На главную',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => ExportService.exportToPdf(widget.resultJson),
            tooltip: 'Экспорт в PDF',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => ExportService.sharePdf(widget.resultJson),
            tooltip: 'Поделиться',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Статус
              _buildStatusCard(result),
              const SizedBox(height: 16),
              
              // Метрики (ТЕПЕРЬ СО ШТОРКОЙ)
              if (isSolvable) _buildMetricsExpansionTile(result),
              const SizedBox(height: 16),
              
              // Таблица с прокруткой
              if (isSolvable) _buildScrollableTable(result),
              
              // КНОПКА: Следующий участок (только если в режиме проекта)
              if (isSolvable && widget.projectId != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _addNextSection(context, result),
                    icon: const Icon(Icons.add_road),
                    label: const Text('СЛЕДУЮЩИЙ УЧАСТОК'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  // Функция добавления следующего участка
  Future<void> _addNextSection(BuildContext context, Map<String, dynamic> result) async {
    if (widget.projectId == null || widget.currentSectionNumber == null) return;
    
    final nextSectionNumber = widget.currentSectionNumber! + 1;
    
    // Участок уже сохранён в InputScreen при расчёте
    // Просто переходим на следующий участок
    
    if (!mounted) return;
    
    // Переходим на InputScreen для следующего участка
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => InputScreen(
          projectId: widget.projectId,
          sectionNumber: nextSectionNumber,
          projectSettings: widget.projectSettings,
        ),
      ),
    );
  }
  
  // Карточка статуса
  Widget _buildStatusCard(Map<String, dynamic> result) {
    final bool isSuccess = result['status'] == 'РЕШАЕМО';
    
    return Card(
      color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result['status'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                  if (!isSuccess && result['error'] != null)
                    Text(
                      result['error'],
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Шторка с метриками (ExpansionTile)
  Widget _buildMetricsExpansionTile(Map<String, dynamic> result) {
    // Используем средний слой из результата расчёта (интегральный метод)
    final double avgS = (result['average_layer'] as num?)?.toDouble() ?? 0.0;
    
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,  // Свёрнуто по умолчанию
        title: const Text(
          'МЕТРИКИ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _buildMetricRow('Решений найдено', '${result['total_solutions'] ?? 0}'),
                _buildMetricRow('Средний слой', '${avgS.toStringAsFixed(2)} мм'),
                _buildMetricRow('Время расчёта', '${(result['computation_time'] as num?)?.toStringAsFixed(3) ?? "—"} сек'),
                _buildMetricRow('Балл решения', result['score']?.toStringAsFixed(2) ?? '—'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  // Таблица с горизонтальной прокруткой
  Widget _buildScrollableTable(Map<String, dynamic> result) {
    final List<double> F = (result['F'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final List<String> T = (result['T'] as List?)?.map((e) => e as String).toList() ?? [];
    final List<double> L = (result['L'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final List<double> P = (result['solution'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final int? vIndex = result['v_index'] as int?;
    
    // Расчёт S
    final List<double> S = [];
    for (int i = 0; i < F.length; i++) {
      S.add(F[i] - P[i]);
    }
    
    // Расчёт k и стрелок (как в Python версии)
    final List<Map<String, dynamic>> slopes = [];
    for (int i = 0; i < L.length; i++) {
      // k_i = abs(P[i] - P[i+1]) / L[i]
      double k = (P[i] - P[i + 1]).abs() / L[i];
      
      // Стрелка для нивелирной рейки:
      // Меньше P = точка ВЫШЕ физически
      // Больше P = точка НИЖЕ физически
      String arrow;
      
      if (vIndex != null) {
        // ЕСТЬ ВОДОРАЗДЕЛ (H0, H2)
        // До водораздела: P уменьшается, точка поднимается → ↑
        // После водораздела: P увеличивается, точка опускается → ↓
        if (i < vIndex) {
          arrow = '↑';  // До водораздела - подъём профиля
        } else if (i == vIndex) {
          arrow = '↑↓'; // На водоразделе - вершина
        } else {
          arrow = '↓';  // После водораздела - спуск профиля
        }
      } else {
        // НЕТ ВОДОРАЗДЕЛА (H3)
        // Направление зависит от изменения P
        double pDiff = P[i] - P[i + 1];
        
        if (pDiff.abs() < 0.001) {
          arrow = '—';  // Горизонт
        } else if (pDiff > 0) {
          // P уменьшается: 1000→960
          // Точка физически ПОДНИМАЕТСЯ
          arrow = '↑';
        } else {
          // P увеличивается: 930→1005
          // Точка физически ОПУСКАЕТСЯ
          arrow = '↓';
        }
      }
      
      slopes.add({
        'value': k,
        'arrow': arrow,
      });
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ТАБЛИЦА РЕШЕНИЯ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Горизонтальная прокрутка
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.green.shade100),
                columns: const [
                  DataColumn(label: Text('№', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('F_вх', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Тип', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('S_i', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('P_i', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('L_i', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('k_i', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Стрелка', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: List.generate(F.length, (i) {
                  final bool isWatershed = i == vIndex;
                  final slopeData = i < slopes.length ? slopes[i] : null;
                  
                  return DataRow(
                    color: WidgetStateProperty.all(
                      isWatershed 
                        ? Colors.blue.shade50 
                        : (i % 2 == 0 ? Colors.grey.shade50 : Colors.white)
                    ),
                    cells: [
                      DataCell(Text('$i')),
                      DataCell(Text(F[i].toStringAsFixed(0))), // БЕЗ дробной части
                      DataCell(Text(T[i])),
                      DataCell(Text(S[i].toStringAsFixed(0))), // БЕЗ дробной части
                      DataCell(Text(P[i].toStringAsFixed(1))), // 1 знак
                      DataCell(Text(i < L.length ? L[i].toStringAsFixed(1) : '—')),
                      
                      // k без стрелки
                      DataCell(
                        slopeData != null
                          ? Text(
                              slopeData['value'].toStringAsFixed(2),
                              style: TextStyle(
                                color: slopeData['value'] < 3.0 ? Colors.red : Colors.black,
                                fontWeight: slopeData['value'] < 3.0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            )
                          : const Text('—'),
                      ),
                      
                      // Стрелка отдельно
                      DataCell(
                        slopeData != null
                          ? Text(
                              slopeData['arrow'],
                              style: const TextStyle(fontSize: 18),
                            )
                          : Text(
                              i == F.length - 1 ? '↓' : '—',
                              style: const TextStyle(fontSize: 18),
                            ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
