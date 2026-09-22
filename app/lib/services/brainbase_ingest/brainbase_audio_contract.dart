import 'package:omi/backend/schema/bt_device/bt_device.dart';

/// Audio formats accepted by the Brainbase ingest boundary.
///
/// Keep codec naming and sample-rate selection here so live capture and fixture
/// replay cannot silently describe the same bytes differently.
String brainbaseCodecName(BleAudioCodec codec) => switch (codec) {
      BleAudioCodec.pcm16 => 'pcm16',
      BleAudioCodec.opus => 'opus',
      BleAudioCodec.opusFS320 => 'opus_fs320',
      _ => throw UnsupportedError('Unsupported Brainbase codec: $codec'),
    };

int brainbaseSampleRate(BleAudioCodec codec) => switch (codec) {
      BleAudioCodec.pcm16 => 16000,
      BleAudioCodec.opus => 16000,
      BleAudioCodec.opusFS320 => 16000,
      _ => throw UnsupportedError('Unsupported Brainbase codec: $codec'),
    };

const int brainbaseChannels = 1;
