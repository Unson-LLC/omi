import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omi/backend/schema/bt_device/bt_device.dart';
import 'package:omi/services/audio_sources/audio_source.dart';
import 'package:omi/services/audio_sources/fixture_replay_audio_source.dart';

void main() {
  String digest(List<int> bytes) => sha256.convert(bytes).toString();

  Map<String, Object?> fixtureJson({String? frameHash}) {
    final payload = <int>[0, 1, 2, 3];
    return {
      'schemaVersion': 1,
      'fixtureId': 'synthetic-pcm16-v1',
      'codec': 'pcm16',
      'sampleRate': 16000,
      'channels': 1,
      'events': [
        {'type': 'start', 'atMs': 0},
        {
          'type': 'frame',
          'atMs': 20,
          'sequence': 0,
          'payloadBase64': base64Encode(payload),
          'payloadSha256': frameHash ?? digest(payload),
        },
        {'type': 'stop', 'atMs': 40},
      ],
    };
  }

  test('rejects a replay fixture whose frame hash was changed', () {
    expect(
      () => ReplayFixture.fromJson(
        fixtureJson(frameHash: List.filled(64, '0').join()),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'loads a transcribable synthetic speech fixture committed with the overlay',
    () async {
      final fixtureFile = File('test/fixtures/audio/synthetic_pcm16_v1.json');
      final fixture = ReplayFixture.fromJson(
        Map<String, Object?>.from(
          jsonDecode(await fixtureFile.readAsString()) as Map,
        ),
      );

      expect(fixture.schemaVersion, 1);
      expect(fixture.fixtureId, 'synthetic-ja-speech-pcm16-v1');
      final frames = fixture.events.whereType<ReplayFrameEvent>().toList();
      expect(frames, hasLength(greaterThanOrEqualTo(150)));
      expect(fixture.events.last.atMs, greaterThanOrEqualTo(3000));

      final samples = frames.expand((frame) => frame.payload).toList(growable: false);
      expect(samples.any((byte) => byte != 0), isTrue);
    },
  );

  test('replays lifecycle and WAL frames in deterministic order', () async {
    final fixture = ReplayFixture.fromJson(fixtureJson());
    final lifecycle = <ReplayLifecycle>[];
    final frames = <WalFrame>[];
    final waits = <Duration>[];

    final source = FixtureReplayAudioSource(
      fixture: fixture,
      wait: (duration) async => waits.add(duration),
    );
    await source.replay(onLifecycle: lifecycle.add, onFrames: frames.addAll);

    expect(source.codec, BleAudioCodec.pcm16);
    expect(source.deviceId, 'replay:synthetic-pcm16-v1');
    expect(lifecycle, [ReplayLifecycle.started, ReplayLifecycle.stopped]);
    expect(frames, hasLength(1));
    expect(frames.single.payload, [0, 1, 2, 3]);
    expect(frames.single.syncKey, FrameSyncKey.fromIndex(0));
    expect(waits, [
      const Duration(milliseconds: 20),
      const Duration(milliseconds: 20),
    ]);
  });

  test('rejects skipped frame sequence numbers', () {
    final json = fixtureJson();
    final events = json['events']! as List<Map<String, Object?>>;
    events[1]['sequence'] = 1;

    expect(() => ReplayFixture.fromJson(json), throwsA(isA<FormatException>()));
  });

  test('rejects codecs that the shared Brainbase ingest cannot decode', () {
    final json = fixtureJson();
    json['codec'] = 'pcm8';

    expect(() => ReplayFixture.fromJson(json), throwsA(isA<FormatException>()));
  });

  test('rejects metadata that disagrees with the shared ingest contract', () {
    final wrongRate = fixtureJson()..['sampleRate'] = 8000;
    final stereo = fixtureJson()..['channels'] = 2;

    expect(
      () => ReplayFixture.fromJson(wrongRate),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ReplayFixture.fromJson(stereo),
      throwsA(isA<FormatException>()),
    );
  });
}
