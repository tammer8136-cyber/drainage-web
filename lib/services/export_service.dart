import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/platform_service.dart';

import 'pdf_saver_mobile.dart' if (dart.library.html) 'pdf_saver_web.dart';

class ExportService {
  static Future<void> exportToPdf(String resultJson) async {
    final result = jsonDecode(resultJson);
    final pdf = pw.Document();

    late pw.Font font;
    late pw.Font fontBold;

    try {
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final fontBoldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      font = pw.Font.ttf(fontData);
      fontBold = pw.Font.ttf(fontBoldData);
    } catch (_) {
      font = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
    }

    final F = (result['F'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final T = (result['T'] as List?)?.map((e) => e as String).toList() ?? [];
    final L = (result['L'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final P = (result['solution'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final vIndex = result['v_index'] as int?;

    final S = <double>[];
    for (int i = 0; i < F.length; i++) {
      S.add(F[i] - P[i]);
    }

    final k = <double>[];
    final arrows = <String>[];
    for (int i = 0; i < L.length; i++) {
      k.add((P[i] - P[i + 1]).abs() / L[i]);
      if (vIndex != null) {
        if (i < vIndex) {
          arrows.add('^');
        } else if (i == vIndex) {
          arrows.add('^v');
        } else {
          arrows.add('v');
        }
      } else {
        final pDiff = P[i] - P[i + 1];
        if (pDiff.abs() < 0.001) {
          arrows.add('-');
        } else if (pDiff > 0) {
          arrows.add('^');
        } else {
          arrows.add('v');
        }
      }
    }

    // Средний слой — из JSON (взвешенный интегральный, посчитан в optimizer)
    final double avgS = (result['average_layer'] as num?)?.toDouble() ?? 0.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Результат расчета продольного профиля',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 20),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('МЕТРИКИ',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text('Статус: ${result['status']}'),
                    pw.Text('Решений найдено: ${result['total_solutions'] ?? 0}'),
                    pw.Text('Средний слой: ${avgS.toStringAsFixed(2)} мм'),
                    pw.Text('Балл решения: ${result['score']?.toStringAsFixed(2) ?? "—"}'),
                    pw.Text('Время расчёта: ${result['computation_time']?.toStringAsFixed(3) ?? "—"} сек'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              pw.Text('ТАБЛИЦА РЕШЕНИЯ',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildCell('№', font),
                      _buildCell('F_вх', font),
                      _buildCell('Тип', font),
                      _buildCell('S_i', font),
                      _buildCell('P_i', font),
                      _buildCell('L_i', font),
                      _buildCell('k_i', font),
                      _buildCell('Напр.', font),
                    ],
                  ),
                  for (int i = 0; i < F.length; i++)
                    pw.TableRow(
                      children: [
                        _buildCell('$i', font),
                        _buildCell(F[i].toStringAsFixed(0), font),
                        _buildCell(T[i], font),
                        _buildCell(S[i].toStringAsFixed(0), font),
                        _buildCell(P[i].toStringAsFixed(1), font),
                        _buildCell(i < L.length ? L[i].toStringAsFixed(1) : '—', font),
                        _buildCell(i < k.length ? k[i].toStringAsFixed(2) : '—', font),
                        _buildCell(i < arrows.length ? arrows[i] : '-', font),
                      ],
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final filename = 'drainage_result_$timestamp.pdf';

    if (PlatformService.isWeb) {
      await savePdfWeb(bytes, filename);
    } else {
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    }
  }

  static pw.Widget _buildCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 10, font: font),
          textAlign: pw.TextAlign.center),
    );
  }

  static Future<void> sharePdf(String resultJson) async {
    await exportToPdf(resultJson);
  }

  /// Экспорт сводного PDF по всему проекту
  static Future<void> exportProjectToPdf({
    required String projectName,
    required List<Map<String, dynamic>> sections,
  }) async {
    final pdf = pw.Document();

    late pw.Font font;
    late pw.Font fontBold;

    try {
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final fontBoldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      font = pw.Font.ttf(fontData);
      fontBold = pw.Font.ttf(fontBoldData);
    } catch (_) {
      font = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
    }

    double totalLength = 0;
    double weightedLayerSum = 0;

    for (final section in sections) {
      final resultJson = section['result_json'] as String? ?? '';
      if (resultJson.isEmpty) continue;
      try {
        final result = jsonDecode(resultJson);
        final L = (result['L'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
        final sectionLength = L.fold<double>(0, (a, b) => a + b);
        final avgLayer = (result['average_layer'] as num?)?.toDouble() ?? 0.0;
        totalLength += sectionLength;
        weightedLayerSum += avgLayer * sectionLength;
      } catch (_) {}
    }

    final overallAvgLayer = totalLength > 0 ? weightedLayerSum / totalLength : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          pw.Text('Сводный отчёт проекта: $projectName',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}'),
          pw.SizedBox(height: 20),

          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('СВОДКА',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Участков: ${sections.length}'),
                pw.Text('Общая длина: ${totalLength.toStringAsFixed(1)} м'),
                pw.Text('Средний слой (взвешенный): ${overallAvgLayer.toStringAsFixed(1)} мм'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          pw.Text('УЧАСТКИ',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildCell('№', font),
                  _buildCell('Название', font),
                  _buildCell('Длина, м', font),
                  _buildCell('Ср. слой, мм', font),
                  _buildCell('Статус', font),
                ],
              ),
              for (int i = 0; i < sections.length; i++) ...[
                () {
                  final section = sections[i];
                  final resultJson = section['result_json'] as String? ?? '';
                  double sectionLength = 0;
                  double avgLayer = 0;
                  String status = '—';
                  if (resultJson.isNotEmpty) {
                    try {
                      final result = jsonDecode(resultJson);
                      final L = (result['L'] as List?)
                              ?.map((e) => (e as num).toDouble())
                              .toList() ??
                          [];
                      sectionLength = L.fold<double>(0, (a, b) => a + b);
                      avgLayer =
                          (result['average_layer'] as num?)?.toDouble() ?? 0.0;
                      status = result['status'] as String? ?? '—';
                    } catch (_) {}
                  }
                  return pw.TableRow(children: [
                    _buildCell('${i + 1}', font),
                    _buildCell(section['name'] as String? ?? '—', font),
                    _buildCell(sectionLength.toStringAsFixed(1), font),
                    _buildCell(avgLayer.toStringAsFixed(1), font),
                    _buildCell(status, font),
                  ]);
                }(),
              ],
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final filename = 'drainage_project_${projectName}_$timestamp.pdf';

    if (PlatformService.isWeb) {
      await savePdfWeb(bytes, filename);
    } else {
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    }
  }
}
