import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/platform_service.dart';

// Условный импорт для веб-специфичного сохранения PDF
import 'pdf_saver_mobile.dart' if (dart.library.html) 'pdf_saver_web.dart';

class ExportService {
  static Future<void> exportToPdf(String resultJson) async {
    final result = jsonDecode(resultJson);
    final pdf = pw.Document();
    
    // Загружаем TTF шрифты из assets
    late pw.Font font;
    late pw.Font fontBold;
    
    try {
      // Пытаемся загрузить пользовательские TTF шрифты
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final fontBoldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      
      font = pw.Font.ttf(fontData);
      fontBold = pw.Font.ttf(fontBoldData);
    } catch (e) {
      // Если файлы не найдены, используем Google Fonts как fallback
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
      
      // Текстовые обозначения вместо стрелок (для надёжности в PDF)
      if (vIndex != null) {
        // ЕСТЬ ВОДОРАЗДЕЛ (H0, H2)
        if (i < vIndex) {
          arrows.add('^');  // Подъём
        } else if (i == vIndex) {
          arrows.add('^v'); // Водораздел
        } else {
          arrows.add('v');  // Спуск
        }
      } else {
        // НЕТ ВОДОРАЗДЕЛА (H3)
        double pDiff = P[i] - P[i + 1];
        
        if (pDiff.abs() < 0.001) {
          arrows.add('-');  // Горизонт
        } else if (pDiff > 0) {
          arrows.add('^');  // Подъём
        } else {
          arrows.add('v');  // Спуск
        }
      }
    }
    
    double avgS = 0;
    int count = 0;
    for (int i = 0; i < T.length; i++) {
      if (T[i] != 'PR') {
        double sEff = S[i];
        if (T[i] == 'P') sEff = 50;
        avgS += sEff;
        count++;
      }
    }
    avgS = count > 0 ? avgS / count : 0;
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
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
                    pw.Text('МЕТРИКИ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
              
              pw.Text('ТАБЛИЦА РЕШЕНИЯ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
                        _buildCell(i < arrows.length ? arrows[i] : '-', font), // ASCII символ для последней строки
                      ],
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
    
    // Сохраняем PDF
    final bytes = await pdf.save();
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final filename = 'drainage_result_$timestamp.pdf';
    
    if (PlatformService.isWeb) {
      // Web: скачивание файла через браузер
      await savePdfWeb(bytes, filename);
    } else {
      // Mobile: открытие диалога печати/сохранения
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    }
  }
  
  static pw.Widget _buildCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10, font: font), textAlign: pw.TextAlign.center),
    );
  }
  
  static Future<void> sharePdf(String resultJson) async {
    if (PlatformService.isWeb) {
      // На Web просто скачиваем файл (share не поддерживается)
      await exportToPdf(resultJson);
    } else {
      // На Mobile используем share
      // TODO: Реализовать полную генерацию PDF (пока используем exportToPdf)
      await exportToPdf(resultJson);
    }
  }
}
