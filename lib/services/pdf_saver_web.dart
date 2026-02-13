/// Web-специфичная реализация сохранения PDF
/// Использует package:web для скачивания файлов через браузер

import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Сохранить PDF файл в Web браузере
Future<void> savePdfWeb(List<int> bytes, String filename) async {
  // Конвертируем List<int> в Uint8List
  final uint8list = Uint8List.fromList(bytes);
  
  // Создаём Blob из байтов PDF
  final blob = web.Blob(
    [uint8list.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  
  // Создаём URL для blob
  final url = web.URL.createObjectURL(blob);
  
  // Создаём невидимую ссылку и кликаем по ней
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  
  // Освобождаем память
  web.URL.revokeObjectURL(url);
}
