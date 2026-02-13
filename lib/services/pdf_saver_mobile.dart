/// Mobile-специфичная заглушка для сохранения PDF
/// На мобильных платформах не используется (там используется Printing)

/// Заглушка для мобильных платформ
Future<void> savePdfWeb(List<int> bytes, String filename) async {
  throw UnsupportedError('savePdfWeb is only supported on Web platform');
}
