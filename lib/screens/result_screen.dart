import 'package:flutter/material.dart';
import 'package:drainage_app/services/export_service.dart';
import 'input_screen.dart';
import 'dart:convert';

/// Экран результата с прокруткой и стрелками уклонов
class ResultScreen extends StatefulWidget {
  final String resultJson;
  final int? projectId;
  final int? currentSectionNumber;
  final Map<String, dynamic>? projectSettings;
  final bool useMeters;
  final String elevationMode; // 'rod' | 'absolute'
  final String giMode; // 'auto' | 'manual' — только если elevationMode == 'absolute'
  final double? gi; // горизонт, мм
  
  const ResultScreen({
    super.key,
    required this.resultJson,
    this.projectId,
    this.currentSectionNumber,
    this.projectSettings,
    this.useMeters = false,
    this.elevationMode = 'rod',
    this.giMode = 'auto',
    this.gi,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {

  // Только для elevationMode=='absolute' && giMode=='manual' — переключатель
  // "по рейке" / "абсолютная" на экране результата. В auto-режиме этот
  // тумблер не нужен — там показывается только абсолютная отметка.
  bool _showAbsolute = true;

  bool get _isAbsoluteMode => widget.elevationMode == 'absolute' && widget.gi != null;
  bool get _showAbsoluteNow => _isAbsoluteMode && (widget.giMode == 'auto' || _showAbsolute);

  /// F/P — отсчёты по рейке, хранятся всегда в мм. В обычном режиме
  /// переключатель useMeters влияет только на формат (мм целыми, или м с
  /// тремя знаками). В режиме абсолютных отметок — конвертируем через ГИ
  /// (auto: всегда так; manual: только если включён тумблер на экране).
  String _fmtElevation(double mm) {
    if (_showAbsoluteNow) {
      final absoluteMm = widget.gi! - mm;
      return (absoluteMm / 1000).toStringAsFixed(3);
    }
    if (widget.useMeters) {
      return (mm / 1000).toStringAsFixed(3);
    }
    return mm.toStringAsFixed(0);
  }
  
  @override
  Widget build(BuildContext context) {
    final result = jsonDecode(widget.resultJson);
    final bool isSolvable = result['status'] == 'РЕШАЕМО';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Результат'),
        actions: [
          // Переключатель "по рейке" / "абсолютная" — только когда горизонт
          // задан вручную (в auto-режиме показывается только абсолютная,
          // переключать нечего).
          if (widget.elevationMode == 'absolute' && widget.giMode == 'manual' && widget.gi != null)
            IconButton(
              icon: Icon(_showAbsolute ? Icons.straighten : Icons.height),
              tooltip: _showAbsolute ? 'Показать по рейке' : 'Показать абсолютную',
              onPressed: () => setState(() => _showAbsolute = !_showAbsolute),
            ),
          // Кнопка "На главную" — возврат к первому экрану
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
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
              _buildStatusCard(result),
              const SizedBox(height: 16),
              
              if (isSolvable) _buildMetricsExpansionTile(result),
              const SizedBox(height: 16),
              
              if (isSolvable) _buildScrollableTable(result),
              
              // Кнопка следующего участка (только в режиме проекта)
              if (isSolvable && widget.projectId != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _addNextSection(context),
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
  
  /// Переход к следующему участку.
  /// Участок уже сохранён в InputScreen при расчёте, здесь только навигация.
  Future<void> _addNextSection(BuildContext context) async {
    if (widget.projectId == null || widget.currentSectionNumber == null) return;
    
    final nextSectionNumber = widget.currentSectionNumber! + 1;
    
    if (!mounted) return;
    
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
  
  Widget _buildMetricsExpansionTile(Map<String, dynamic> result) {
    final double avgS = (result['average_layer'] as num?)?.toDouble() ?? 0.0;
    
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        title: const Text(
          'МЕТРИКИ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          Text('$label:', style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildScrollableTable(Map<String, dynamic> result) {
    final List<double> F = (result['F'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final List<String> T = (result['T'] as List?)?.map((e) => e as String).toList() ?? [];
    final List<double> L = (result['L'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final List<double> P = (result['solution'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final int? vIndex = result['v_index'] as int?;
    
    final List<double> S = [];
    for (int i = 0; i < F.length; i++) {
      S.add(F[i] - P[i]);
    }
    
    final List<Map<String, dynamic>> slopes = [];
    for (int i = 0; i < L.length; i++) {
      double k = (P[i] - P[i + 1]).abs() / L[i];
      String arrow;
      
      if (vIndex != null && vIndex >= 0) {
        if (i < vIndex) {
          arrow = '↑';
        } else if (i == vIndex) {
          arrow = '↑↓';
        } else {
          arrow = '↓';
        }
      } else {
        double pDiff = P[i] - P[i + 1];
        if (pDiff.abs() < 0.001) {
          arrow = '—';
        } else if (pDiff > 0) {
          arrow = '↑';
        } else {
          arrow = '↓';
        }
      }
      
      slopes.add({'value': k, 'arrow': arrow});
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ТАБЛИЦА РЕШЕНИЯ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.green.shade100),
                columns: [
                  const DataColumn(label: Text('№', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('F_вх${_showAbsoluteNow ? " (абс), м" : (widget.useMeters ? ", м" : "")}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Тип', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('S_i', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('P_i${_showAbsoluteNow ? " (абс), м" : (widget.useMeters ? ", м" : "")}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('L_i', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('k_i', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Стрелка', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: List.generate(F.length, (i) {
                  final bool isWatershed = i == vIndex;

                  // Продольный уклон показываем так, чтобы строка
                  // водораздела осталась пустой: до водораздела — уклон до
                  // следующей точки (как раньше), после — уклон от
                  // предыдущей. Каждый сегмент по-прежнему показан ровно
                  // один раз, но на самом водоразделе цифры нет — там
                  // уклон меняет направление, и одно число сбивало.
                  int? segIdx;
                  if (vIndex != null && vIndex >= 0) {
                    if (i < vIndex) {
                      segIdx = i;
                    } else if (i > vIndex) {
                      segIdx = i - 1;
                    }
                  } else {
                    segIdx = i;
                  }

                  final slopeData =
                      (segIdx != null && segIdx < slopes.length) ? slopes[segIdx] : null;
                  final lengthText =
                      (segIdx != null && segIdx < L.length) ? L[segIdx].toStringAsFixed(1) : '—';
                  
                  return DataRow(
                    color: WidgetStateProperty.all(
                      isWatershed
                          ? Colors.blue.shade50
                          : (i % 2 == 0 ? Colors.grey.shade50 : Colors.white),
                    ),
                    cells: [
                      DataCell(Text('$i')),
                      DataCell(Text(_fmtElevation(F[i]))),
                      DataCell(Text(T[i])),
                      DataCell(Text(S[i].toStringAsFixed(0))),
                      DataCell(Text(_fmtElevation(P[i]))),
                      DataCell(Text(lengthText)),
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
                      DataCell(
                        i < slopes.length
                            ? Text(slopes[i]['arrow'], style: const TextStyle(fontSize: 18))
                            : const Text('—', style: TextStyle(fontSize: 18)),
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
