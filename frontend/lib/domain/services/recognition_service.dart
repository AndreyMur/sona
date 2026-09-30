import '../models/recognition.dart';

/// Порт распознавания речи (STT) через прокси OdiRouter.
abstract interface class SpeechRecognitionService {
  /// Отправляет аудиофайл [audioPath] на распознавание.
  ///
  /// [quality] — `standard` или `max` (для тарифа Pro).
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String quality = 'standard',
    String language = 'ru',
  });
}

/// Порт разбора текста в структуру операций (NLU) через прокси OdiRouter.
abstract interface class TextParsingService {
  /// Разбирает текст [text] в список операций.
  Future<ParseResult> parse(String text);
}
