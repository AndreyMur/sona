import 'package:record/record.dart';

import '../../domain/services/audio_recorder.dart';

/// Реализация записи аудио через пакет `record`.
///
/// Формат — AAC-LC в контейнере MPEG-4 (`.m4a`), 16 кГц, mono, что
/// соответствует требованиям STT.
class RecordAudioRecorderService implements AudioRecorderPort {
  RecordAudioRecorderService([AudioRecorder? recorder])
    : _recorder = recorder ?? AudioRecorder();

  /// Конфигурация записи: `.m4a` (16 кГц, mono).
  static const RecordConfig recordConfig = RecordConfig(
    encoder: AudioEncoder.aacLc,
    sampleRate: 16000,
    numChannels: 1,
    bitRate: 64000,
  );

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(recordConfig, path: path);

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}
