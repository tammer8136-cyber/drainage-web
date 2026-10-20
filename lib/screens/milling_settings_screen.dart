import 'package:flutter/material.dart';
import '../services/milling/models/milling_models.dart';
import '../services/milling/models/milling_types.dart';

/// Настройки расчёта фрезы. Все допуски и пороги редактируются — та же
/// гибкость, что и в дренажном расчёте.
class MillingSettingsScreen extends StatefulWidget {
  final MillingSettings current;

  const MillingSettingsScreen({super.key, required this.current});

  @override
  State<MillingSettingsScreen> createState() => _MillingSettingsScreenState();
}

class _MillingSettingsScreenState extends State<MillingSettingsScreen> {
  late TextEditingController _kMin;
  late TextEditingController _delta;
  late TextEditingController _overlay;
  late TextEditingController _targetCut;
  late Map<String, List<TextEditingController>> _tol;
  late TextEditingController _bortMin;
  late TextEditingController _bortMax;
  late bool _checkBort;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _kMin = TextEditingController(text: c.kMin.toString());
    _delta = TextEditingController(text: c.delta.toString());
    _overlay = TextEditingController(text: c.overlay.toStringAsFixed(0));
    _targetCut = TextEditingController(text: c.targetCut.toStringAsFixed(0));
    _tol = {
      for (final e in c.tolerance.entries)
        e.key: [
          TextEditingController(text: e.value[0].toString()),
          TextEditingController(text: e.value[1].toString()),
        ],
    };
    _bortMin = TextEditingController(text: c.bortExposureMin.toStringAsFixed(0));
    _bortMax = TextEditingController(text: c.bortExposureMax.toStringAsFixed(0));
    _checkBort = c.checkBortExposure;
  }

  @override
  void dispose() {
    _kMin.dispose();
    _delta.dispose();
    _overlay.dispose();
    _targetCut.dispose();
    for (final pair in _tol.values) {
      for (final c in pair) {
        c.dispose();
      }
    }
    _bortMin.dispose();
    _bortMax.dispose();
    super.dispose();
  }

  void _save() {
    final s = MillingSettings(
      kMin: double.tryParse(_kMin.text),
      delta: int.tryParse(_delta.text),
      overlay: double.tryParse(_overlay.text),
      targetCut: double.tryParse(_targetCut.text),
      tolerance: {
        for (final e in _tol.entries)
          e.key: [
            int.tryParse(e.value[0].text) ?? 0,
            int.tryParse(e.value[1].text) ?? 0,
          ],
      },
      bortExposureMin: double.tryParse(_bortMin.text),
      bortExposureMax: double.tryParse(_bortMax.text),
      checkBortExposure: _checkBort,
    );

    final err = s.validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.pop(context, s);
  }

  void _reset() {
    final d = MillingSettings.defaults();
    setState(() {
      _kMin.text = d.kMin.toString();
      _delta.text = d.delta.toString();
      _overlay.text = d.overlay.toStringAsFixed(0);
      _targetCut.text = d.targetCut.toStringAsFixed(0);
      for (final e in d.tolerance.entries) {
        _tol[e.key]?[0].text = e.value[0].toString();
        _tol[e.key]?[1].text = e.value[1].toString();
      }
      _bortMin.text = d.bortExposureMin.toStringAsFixed(0);
      _bortMax.text = d.bortExposureMax.toStringAsFixed(0);
      _checkBort = d.checkBortExposure;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки — фреза')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_kMin, 'Минимальный продольный уклон, ‰'),
          _field(_delta, 'Шаг перебора отметок, мм'),
          _field(_overlay, 'Толщина укладки, мм'),
          _field(_targetCut, 'Целевой срез, мм'),
          const SizedBox(height: 16),
          const Text('Допуски среза, мм',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final key in _tol.keys) _tolRow(key),
          const SizedBox(height: 16),
          const Text('Оголение борта',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Card(
            child: SwitchListTile(
              title: const Text('Проверять оголение'),
              subtitle: const Text(
                'Z_борт − Z_проект, мм',
                style: TextStyle(fontSize: 11),
              ),
              value: _checkBort,
              onChanged: (v) => setState(() => _checkBort = v),
            ),
          ),
          const SizedBox(height: 8),
          if (_checkBort)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bortMin,
                      decoration: const InputDecoration(
                        labelText: 'от, мм', isDense: true, border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _bortMax,
                      decoration: const InputDecoration(
                        labelText: 'до, мм', isDense: true, border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  child: const Text('СБРОСИТЬ'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('СОХРАНИТЬ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Поперечный уклон в водоразделе: не ниже '
            '${MillingTypes.crossSlopeHardFloor.toStringAsFixed(0)}‰',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _label(String key) {
    switch (key) {
      case 'DK':
        return 'ДК';
      case 'WD':
        return 'Водор.';
      case 'O':
        return 'Обыч.';
      case 'PR':
        return 'Примык.';
      default:
        return key;
    }
  }

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: c,
          decoration: InputDecoration(
            labelText: label, isDense: true, border: const OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      );

  Widget _tolRow(String key) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 60, child: Text(_label(key))),
            Expanded(
              child: TextField(
                controller: _tol[key]![0],
                decoration: const InputDecoration(
                  labelText: 'мин', isDense: true, border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _tol[key]![1],
                decoration: const InputDecoration(
                  labelText: 'макс', isDense: true, border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      );
}
