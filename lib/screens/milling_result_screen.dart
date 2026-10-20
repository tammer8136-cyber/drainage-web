import 'package:flutter/material.dart';
import 'dart:convert';

import '../services/milling/models/milling_models.dart';
import 'milling_input_screen.dart';

/// Результат перепрофилирования края под фрезу.
class MillingResultScreen extends StatelessWidget {
  final String resultJson;

  /// Режим проекта — тогда снизу появляется переход к следующему участку.
  final int? projectId;
  final int? currentSectionNumber;
  final MillingSettings? projectSettings;

  const MillingResultScreen({
    super.key,
    required this.resultJson,
    this.projectId,
    this.currentSectionNumber,
    this.projectSettings,
  });

  @override
  Widget build(BuildContext context) {
    final result = MillingResult.fromJson(
      jsonDecode(resultJson) as Map<String, dynamic>,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Результат — фреза'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'На главную',
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusCard(result),
            const SizedBox(height: 16),
            if (result.isSolvable) ...[
              _metricsCard(result),
              const SizedBox(height: 16),
              _table(result),
              const SizedBox(height: 16),
              _legend(),
            ],
            if (projectId != null && currentSectionNumber != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MillingInputScreen(
                          projectId: projectId,
                          sectionNumber: currentSectionNumber! + 1,
                          projectSettings: projectSettings,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('Участок ${currentSectionNumber! + 1}'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusCard(MillingResult r) {
    final ok = r.isSolvable;
    return Card(
      color: ok ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle : Icons.error,
                color: ok ? Colors.green : Colors.red, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.status,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: ok ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                  if (!ok && r.error != null)
                    Text(r.error!, style: TextStyle(color: Colors.red.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricsCard(MillingResult r) {
    final wd = r.watershedIndex != null && r.watershedIndex! < r.nodes.length
        ? r.nodes[r.watershedIndex!]
        : null;
    final cuts = r.nodes.map((n) => n.cutDepth).toList();
    final minCut = cuts.reduce((a, b) => a < b ? a : b);
    final maxCut = cuts.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Метод', r.algorithm == 'H2' ? 'с водоразделом (H2)' : 'без водораздела (H3)'),
            if (wd != null)
              _row(
                'Водораздел',
                'на ${wd.along.toStringAsFixed(1)} м'
                '${wd.isVirtual ? " (между станциями)" : ""}',
              ),
            _row('Срез', '${minCut.toStringAsFixed(0)}–${maxCut.toStringAsFixed(0)} мм'),
            _row('Укладка', '${r.overlay.toStringAsFixed(0)} мм'),
            _row(
              'Оголение борта',
              r.checkBortExposure
                  ? '${r.bortExposureMin.toStringAsFixed(0)}–'
                    '${r.bortExposureMax.toStringAsFixed(0)} мм'
                  : 'проверка выключена',
            ),
            _row('Балл', r.score.isFinite ? r.score.toStringAsFixed(2) : '—'),
            _row('Время расчёта', '${r.computationTime.toStringAsFixed(3)} сек'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label:', style: const TextStyle(color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _table(MillingResult r) {
    final n = r.nodes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ТАБЛИЦА',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                headingRowColor: WidgetStateProperty.all(Colors.amber.shade100),
                columns: const [
                  DataColumn(label: Text('м', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Тип', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Край', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Фреза', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Проект', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('i_прод', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('i_попер', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Оголение', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: List.generate(n.length, (i) {
                  final node = n[i];
                  final isWd = node.type == 'WD';

                  // Продольный уклон: строка водораздела пустая, до него —
                  // сегмент вперёд, после — сегмент назад. Каждый сегмент
                  // показан ровно один раз.
                  final wIdx = r.watershedIndex;
                  int? segIdx;
                  if (wIdx != null && wIdx >= 0) {
                    if (i < wIdx) {
                      segIdx = i;
                    } else if (i > wIdx) {
                      segIdx = i - 1;
                    }
                  } else {
                    segIdx = i;
                  }

                  String longSlope = '—';
                  if (segIdx != null && segIdx < n.length - 1) {
                    final d = n[segIdx + 1].along - n[segIdx].along;
                    if (d > 0) {
                      longSlope =
                          ((n[segIdx + 1].cutLine - n[segIdx].cutLine).abs() / d)
                              .toStringAsFixed(2);
                    }
                  }

                  final cross = node.crossSlope(r.overlay);
                  final exposure = node.bortExposure(r.overlay);
                  // Оголение проверяется с обеих сторон: и недобор, и
                  // перебор одинаково плохи.
                  final exposureBad = r.checkBortExposure &&
                      exposure != null &&
                      (exposure < r.bortExposureMin - 1e-6 ||
                          exposure > r.bortExposureMax + 1e-6);

                  return DataRow(
                    color: WidgetStateProperty.all(
                      isWd ? Colors.blue.shade50
                           : (i % 2 == 0 ? Colors.grey.shade50 : Colors.white),
                    ),
                    cells: [
                      DataCell(Text(node.along.toStringAsFixed(1) +
                          (node.isVirtual ? '*' : ''))),
                      DataCell(Text(node.type)),
                      DataCell(Text(node.fEdge.toStringAsFixed(0))),
                      DataCell(Text(
                        node.cutDepth.toStringAsFixed(0),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: (node.cutDepth - r.targetCut).abs() <= 1
                              ? Colors.green.shade800
                              : Colors.black,
                        ),
                      )),
                      DataCell(Text(node.finalProject(r.overlay).toStringAsFixed(0))),
                      DataCell(Text(longSlope)),
                      DataCell(Text(
                        cross.toStringAsFixed(1),
                        style: TextStyle(
                          color: cross < 0 ? Colors.red : Colors.black,
                          fontWeight: cross < 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      )),
                      DataCell(Text(
                        exposure == null ? '—' : exposure.toStringAsFixed(0),
                        style: TextStyle(
                          color: exposureBad ? Colors.red : Colors.black,
                          fontWeight: exposureBad ? FontWeight.bold : FontWeight.normal,
                        ),
                      )),
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

  Widget _legend() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '* — водораздел между станциями (ось и борт интерполированы).\n'
          'Проект — с укладкой. i_прод / i_попер — ‰.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      );
}
