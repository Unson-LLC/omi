import 'package:flutter_test/flutter_test.dart';
import 'package:omi/backend/schema/bt_device/bt_device.dart';
import 'package:omi/services/brainbase_ingest/brainbase_audio_contract.dart';

void main() {
  test('defines the metadata sent for every supported ingest codec', () {
    expect(brainbaseCodecName(BleAudioCodec.pcm16), 'pcm16');
    expect(brainbaseCodecName(BleAudioCodec.opus), 'opus');
    expect(brainbaseCodecName(BleAudioCodec.opusFS320), 'opus_fs320');
    expect(brainbaseSampleRate(BleAudioCodec.pcm16), 16000);
    expect(brainbaseSampleRate(BleAudioCodec.opus), 16000);
    expect(brainbaseSampleRate(BleAudioCodec.opusFS320), 16000);
    expect(brainbaseChannels, 1);
  });

  test('rejects a codec that the ingest transcoder does not support', () {
    expect(
      () => brainbaseCodecName(BleAudioCodec.pcm8),
      throwsUnsupportedError,
    );
    expect(
      () => brainbaseSampleRate(BleAudioCodec.pcm8),
      throwsUnsupportedError,
    );
  });
}
