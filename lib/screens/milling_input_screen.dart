import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'dart:convert';

import '../repositories/repository_factory.dart';
import '../repositories/data_repository.dart';
import '../services/milling/models/milling_models.dart';
import '../services/milling/models/milling_types.dart';
import '../services/milling/api/milling_actions.dart';
import 'milling_result_screen.dart';
import 'milling_settings_screen.dart';

/// Перепрофилирование края под фрезу.
/// Ввод по станциям: пара «ось + край», поперечное расстояние между ними,
/// борт (для проверки оголения), продольное расстояние до следующей станции.
/// Ось НЕ пересчитывается — перепроектируется только край.
class MillingInputScreen extends StatefulWidget {
  /// Режим проекта: участок сохраняется в БД. null — разовый расчёт.
  final int? projectId;
  final int? sectionNumber;
  final MillingSettings? projectSettings;

  const MillingInputScreen({
    super.key,
    this.projectId,
    this.sectionNumber,
    this.projectSettings,
  });

  @override
  State<MillingInputScreen> createState() => _MillingInputScreenState();
}

class _MillingInputScreenState extends State<MillingInputScreen> {
  final List<MillingStation> stations = [
    MillingStation(fEdge: 0, fAxis: 0, crossL: 3, length: 10, type: 'DK'),
    MillingStation(fEdge: 0, fAxis: 0, crossL: 3, length: 10, type: 'O'),
    MillingStation(fEdge: 0, fAxis: 0, crossL: 3, length: 0, type: 'DK'),
  ];

  final List<TextEditingController> _edgeCtrl = [];
  final List<TextEditingController> _axisCtrl = [];
  final List<TextEditingController> _bortCtrl = [];
  final List<TextEditingController> _crossCtrl = [];
  final List<TextEditingController> _lenCtrl = [];

  MillingSettings settings = MillingSettings.defaults();
  bool isCalculating = false;

  @override
  void initState() {
    super.initState();
    if (widget.projectSettings != null) settings = widget.projectSettings!;
    _syncControllers();
  }

  void _syncControllers() {
    while (_edgeCtrl.length < stations.length) {
      final i = _edgeCtrl.length;
      _edgeCtrl.add(TextEditingController(text: _num(stations[i].fEdge)));
      _axisCtrl.add(TextEditingController(text: _num(stations[i].fAxis)));
      _bortCtrl.add(TextEditingController(text: stations[i].fBort == null ? '' : _num(stations[i].fBort!)));
      _crossCtrl.add(TextEditingController(text: _num(stations[i].crossL)));
      _lenCtrl.add(TextEditingController(text: _num(stations[i].length)));
    }
    while (_edgeCtrl.length > stations.length) {
      _edgeCtrl.removeLast().dispose();
      _axisCtrl.removeLast().dispose();
      _bortCtrl.removeLast().dispose();
      _crossCtrl.removeLast().dispose();
      _lenCtrl.removeLast().dispose();
    }
  }

  String _num(double v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void dispose() {
    for (final c in [..._edgeCtrl, ..._axisCtrl, ..._bortCtrl, ..._crossCtrl, ..._lenCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectId != null
            ? 'Фреза — участок ${widget.sectionNumber}'
            : 'Фреза — перепрофилирование края'),
        backgroundColor: Colors.amber.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Настройки расчёта',
            onPressed: () async {
              final updated = await Navigator.push<MillingSettings>(
                context,
                MaterialPageRoute(
                  builder: (context) => MillingSettingsScreen(current: settings),
                ),
              );
              if (updated != null) setState(() => settings = updated);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.amber.shade50,
            child: Text(
              'Отсчёты по рейке, мм • K_min ${settings.kMin.toStringAsFixed(1)}‰ • '
              'укладка ${settings.overlay.toStringAsFixed(0)} мм • '
              'целевой срез ${settings.targetCut.toStringAsFixed(0)} мм',
              style: TextStyle(fontSize: 11, color: Colors.brown.shade700),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: stations.length,
              itemBuilder: (context, i) => _buildStationCard(i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addStation,
                icon: const Icon(Icons.add),
                label: const Text('Добавить станцию'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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

  Widget _buildStationCard(int i) {
    final st = stations[i];
    final isLast = i == stations.length - 1;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(radius: 12, child: Text('$i', style: const TextStyle(fontSize: 11))),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: st.type,
                    decoration: const InputDecoration(
                      labelText: 'Тип', isDense: true, border: OutlineInputBorder(),
                    ),
                    items: MillingTypes.inputTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => st.type = v ?? 'O'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: stations.length > 2 ? () => _removeStation(i) : null,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _edgeCtrl[i],
                    decoration: const InputDecoration(
                      labelText: 'Край', isDense: true, border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => st.fEdge = double.tryParse(v) ?? 0,
                  ),
                ),
                // Примыкание — реперная точка: A = к асфальту (режем на
                // толщину укладки), F = к фрезеровке (срез 0).
                if (st.type == 'PR') ...[
                  const SizedBox(width: 6),
                  ToggleButtons(
                    constraints: const BoxConstraints(minHeight: 38, minWidth: 34),
                    isSelected: [st.edgeMode == 'A', st.edgeMode == 'F'],
                    onPressed: (idx) =>
                        setState(() => st.edgeMode = idx == 0 ? 'A' : 'F'),
                    children: const [Text('A'), Text('F')],
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _axisCtrl[i],
                    decoration: const InputDecoration(
                      labelText: 'Ось', isDense: true, border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => st.fAxis = double.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 6),
                // Режим оси: A — снято по асфальту, F — по фрезе
                ToggleButtons(
                  constraints: const BoxConstraints(minHeight: 38, minWidth: 34),
                  isSelected: [st.axisMode == 'A', st.axisMode == 'F'],
                  onPressed: (idx) => setState(() => st.axisMode = idx == 0 ? 'A' : 'F'),
                  children: const [Text('A'), Text('F')],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bortCtrl[i],
                    decoration: const InputDecoration(
                      labelText: 'Борт', isDense: true, border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => st.fBort = v.trim().isEmpty ? null : double.tryParse(v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _crossCtrl[i],
                    decoration: const InputDecoration(
                      labelText: 'l ось→край, м', isDense: true, border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => st.crossL = double.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: isLast
                      ? const SizedBox()
                      : TextField(
                          controller: _lenCtrl[i],
                          decoration: const InputDecoration(
                            labelText: 'L до след., м', isDense: true, border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (v) => st.length = double.tryParse(v) ?? 0,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addStation() {
    setState(() {
      // У бывшей последней станции появляется продольная длина до новой
      if (stations.isNotEmpty && stations.last.length == 0) {
        stations.last.length = 10;
        _lenCtrl[stations.length - 1].text = '10';
      }
      stations.add(MillingStation(
        fEdge: 0, fAxis: 0, crossL: stations.isNotEmpty ? stations.last.crossL : 3,
        length: 0, type: 'O',
      ));
      _syncControllers();
    });
  }

  void _removeStation(int i) {
    if (stations.length <= 2) return;
    setState(() {
      stations.removeAt(i);
      _edgeCtrl.removeAt(i).dispose();
      _axisCtrl.removeAt(i).dispose();
      _bortCtrl.removeAt(i).dispose();
      _crossCtrl.removeAt(i).dispose();
      _lenCtrl.removeAt(i).dispose();
      stations.last.length = 0;
      _lenCtrl.last.text = '';
    });
  }

  Future<void> _calculate() async {
    setState(() => isCalculating = true);
    try {
      final stationsJson = jsonEncode(stations.map((s) => s.toJson()).toList());
      final settingsJson = jsonEncode(settings.toJson());

      final resultJson = await compute(calculateMillingIsolate, {
        'stationsJson': stationsJson,
        'settingsJson': settingsJson,
      });

      if (widget.projectId != null && widget.sectionNumber != null) {
        await _saveSection(resultJson, stationsJson, settingsJson);
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MillingResultScreen(
              resultJson: resultJson,
              projectId: widget.projectId,
              currentSectionNumber: widget.sectionNumber,
              projectSettings: settings,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isCalculating = false);
    }
  }

  Future<void> _saveSection(
    String resultJson,
    String stationsJson,
    String settingsJson,
  ) async {
    try {
      final DataRepository db = RepositoryFactory.instance;
      final existing = (await db.getProjectSections(widget.projectId!))
          .where((s) => s['section_number'] == widget.sectionNumber)
          .toList();

      final inputData = {'stations': jsonDecode(stationsJson)};
      final resultData = jsonDecode(resultJson) as Map<String, dynamic>;
      final snapshot = jsonDecode(settingsJson) as Map<String, dynamic>;

      if (existing.isNotEmpty) {
        await db.updateSection(
          id: existing.first['id'],
          inputData: jsonEncode(inputData),
          resultData: jsonEncode(resultData),
          settingsSnapshot: jsonEncode(snapshot),
        );
      } else {
        await db.addSection(
          projectId: widget.projectId!,
          sectionNumber: widget.sectionNumber!,
          inputData: inputData,
          resultData: resultData,
          settingsSnapshot: snapshot,
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
      // Как и в дренаже: не даём участку тихо пропасть — показываем ошибку,
      // а не делаем вид, что всё сохранилось.
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
