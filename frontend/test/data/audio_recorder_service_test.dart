import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:sona/data/services/audio_recorder_service.dart';

void main() {
  test('запись настроена на .m4a 16 кГц mono (AAC-LC)', () {
    final config = RecordAudioRecorderService.recordConfig;

    expect(config.encoder, AudioEncoder.aacLc);
    expect(config.sampleRate, 16000);
    expect(config.numChannels, 1);
  });
}
