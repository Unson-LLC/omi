import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:omi/backend/schema/bt_device/bt_device.dart';
import 'package:omi/services/audio_sources/audio_source.dart';
import 'package:omi/services/brainbase_ingest/brainbase_audio_contract.dart';

enum ReplayLifecycle { started, stopped }

typedef ReplayWait = Future<void> Function(Duration duration);

class ReplayFixture {
  final int schemaVersion;
  final String fixtureId;
  final BleAudioCodec codec;
  final int sampleRate;
  final int channels;
  final List<ReplayFixtureEvent> events;

  const ReplayFixture({
    required this.schemaVersion,
    required this.fixtureId,
    required this.codec,
    required this.sampleRate,
    required this.channels,
    required this.events,
  });

  factory ReplayFixture.fromJson(Map<String, Object?> json) {
    final rawSchemaVersion = json['schemaVersion'];
    if (rawSchemaVersion is! int || rawSchemaVersion != 1) {
      throw FormatException(
        'Unsupported replay schema version: $rawSchemaVersion',
      );
    }
    final schemaVersion = rawSchemaVersion;

    final fixtureId = json['fixtureId'];
    if (fixtureId is! String || !RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(fixtureId)) {
      throw const FormatException('Invalid privacy-safe fixtureId');
    }

    final rawEvents = json['events'];
    if (rawEvents is! List || rawEvents.isEmpty) {
      throw const FormatException('Replay fixture events must not be empty');
    }

    final events = <ReplayFixtureEvent>[];
    var previousAtMs = -1;
    var expectedSequence = 0;
    for (final rawEvent in rawEvents) {
      if (rawEvent is! Map) {
        throw const FormatException('Replay event must be an object');
      }
      final event = ReplayFixtureEvent.fromJson(
        Map<String, Object?>.from(rawEvent),
      );
      if (event.atMs < previousAtMs) {
        throw const FormatException('Replay events must be time ordered');
      }
      if (event is ReplayFrameEvent) {
        if (event.sequence != expectedSequence) {
          throw FormatException(
            'Expected replay frame $expectedSequence, got ${event.sequence}',
          );
        }
        expectedSequence++;
      }
      previousAtMs = event.atMs;
      events.add(event);
    }

    if (events.first is! ReplayStartEvent ||
        events.last is! ReplayStopEvent ||
        events.whereType<ReplayStartEvent>().length != 1 ||
        events.whereType<ReplayStopEvent>().length != 1) {
      throw const FormatException(
        'Replay fixture must contain exactly one start and one final stop',
      );
    }

    final codec = _parseCodec(json['codec']);
    final sampleRate = _positiveInt(json['sampleRate'], 'sampleRate');
    final channels = _positiveInt(json['channels'], 'channels');
    final expectedSampleRate = brainbaseSampleRate(codec);
    if (sampleRate != expectedSampleRate) {
      throw FormatException(
        'Replay sampleRate must be $expectedSampleRate for ${brainbaseCodecName(codec)}',
      );
    }
    if (channels != brainbaseChannels) {
      throw const FormatException(
        'Replay channels must be $brainbaseChannels for Brainbase ingest',
      );
    }

    return ReplayFixture(
      schemaVersion: schemaVersion,
      fixtureId: fixtureId,
      codec: codec,
      sampleRate: sampleRate,
      channels: channels,
      events: List.unmodifiable(events),
    );
  }
}

sealed class ReplayFixtureEvent {
  final int atMs;

  const ReplayFixtureEvent(this.atMs);

  factory ReplayFixtureEvent.fromJson(Map<String, Object?> json) {
    final atMs = json['atMs'];
    if (atMs is! int || atMs < 0) {
      throw const FormatException('Replay event atMs must be non-negative');
    }
    switch (json['type']) {
      case 'start':
        return ReplayStartEvent(atMs);
      case 'stop':
        return ReplayStopEvent(atMs);
      case 'frame':
        final sequence = json['sequence'];
        final encoded = json['payloadBase64'];
        final expectedHash = json['payloadSha256'];
        if (sequence is! int || sequence < 0 || encoded is! String || expectedHash is! String) {
          throw const FormatException('Replay frame fields are invalid');
        }
        late final List<int> payload;
        try {
          payload = base64Decode(encoded);
        } on FormatException {
          throw FormatException('Replay frame $sequence has invalid base64');
        }
        final actualHash = sha256.convert(payload).toString();
        if (actualHash != expectedHash.toLowerCase()) {
          throw FormatException(
            'Replay frame $sequence hash mismatch: expected $expectedHash, actual $actualHash',
          );
        }
        return ReplayFrameEvent(atMs, sequence, List.unmodifiable(payload));
      default:
        throw FormatException('Unknown replay event type: ${json['type']}');
    }
  }
}

class ReplayStartEvent extends ReplayFixtureEvent {
  const ReplayStartEvent(super.atMs);
}

class ReplayStopEvent extends ReplayFixtureEvent {
  const ReplayStopEvent(super.atMs);
}

class ReplayFrameEvent extends ReplayFixtureEvent {
  final int sequence;
  final List<int> payload;

  const ReplayFrameEvent(super.atMs, this.sequence, this.payload);
}

class FixtureReplayAudioSource implements AudioSource {
  static const isBuildEnabled = bool.fromEnvironment(
    'OMI_FIXTURE_REPLAY_ENABLED',
    defaultValue: false,
  );

  final ReplayFixture fixture;
  final ReplayWait _wait;

  FixtureReplayAudioSource({required this.fixture, ReplayWait? wait})
      : _wait = wait ?? ((duration) => Future<void>.delayed(duration));

  Future<void> replay({
    required void Function(ReplayLifecycle lifecycle) onLifecycle,
    required void Function(List<WalFrame> frames) onFrames,
    double speed = 1,
  }) async {
    if (speed <= 0) {
      throw ArgumentError.value(speed, 'speed', 'must be greater than zero');
    }

    var previousAtMs = 0;
    for (final event in fixture.events) {
      final deltaMs = event.atMs - previousAtMs;
      if (deltaMs > 0) {
        await _wait(Duration(milliseconds: (deltaMs / speed).round()));
      }
      switch (event) {
        case ReplayStartEvent():
          onLifecycle(ReplayLifecycle.started);
        case ReplayStopEvent():
          onLifecycle(ReplayLifecycle.stopped);
        case ReplayFrameEvent(:final sequence, :final payload):
          onFrames([
            WalFrame(
              payload: List<int>.unmodifiable(payload),
              syncKey: FrameSyncKey.fromIndex(sequence),
            ),
          ]);
      }
      previousAtMs = event.atMs;
    }
  }

  @override
  List<WalFrame> processBytes(List<int> rawBytes) {
    throw UnsupportedError(
      'Fixture replay is driven by replay(), not hardware bytes',
    );
  }

  @override
  List<int> getSocketPayload(List<int> rawBytes) {
    throw UnsupportedError('Fixture replay does not write to the live socket');
  }

  @override
  List<WalFrame> flush() => const [];

  @override
  BleAudioCodec get codec => fixture.codec;

  @override
  String get deviceId => 'replay:${fixture.fixtureId}';

  @override
  String get deviceModel => 'fixture-replay';
}

int _positiveInt(Object? value, String field) {
  if (value is! int || value <= 0) {
    throw FormatException('$field must be a positive integer');
  }
  return value;
}

BleAudioCodec _parseCodec(Object? value) {
  return switch (value) {
    'pcm16' => BleAudioCodec.pcm16,
    'opus' => BleAudioCodec.opus,
    'opus_fs320' => BleAudioCodec.opusFS320,
    _ => throw FormatException('Unsupported replay codec: $value'),
  };
}
