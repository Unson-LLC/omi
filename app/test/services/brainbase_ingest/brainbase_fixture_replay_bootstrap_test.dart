import 'package:flutter_test/flutter_test.dart';
import 'package:omi/services/brainbase_ingest/brainbase_fixture_replay_bootstrap.dart';

void main() {
  BrainbaseFixtureReplayBootstrap bootstrap({
    bool debug = true,
    bool replayEnabled = true,
    bool replayOnStart = true,
  }) {
    return BrainbaseFixtureReplayBootstrap(
      isDebugBuild: debug,
      isFixtureReplayEnabled: replayEnabled,
      isReplayOnStartEnabled: replayOnStart,
    );
  }

  test('does nothing outside a debug build', () async {
    var loaded = false;
    final result = await bootstrap(debug: false).runOnce(
      loadFixture: (_) async {
        loaded = true;
        return '{}';
      },
      replay: (_) async {},
    );

    expect(result, isFalse);
    expect(loaded, isFalse);
  });

  test('requires both explicit replay flags', () async {
    var loaded = false;
    Future<String> loadFixture(String _) async {
      loaded = true;
      return '{}';
    }

    expect(
      await bootstrap(replayEnabled: false).runOnce(loadFixture: loadFixture, replay: (_) async {}),
      isFalse,
    );
    expect(
      await bootstrap(replayOnStart: false).runOnce(loadFixture: loadFixture, replay: (_) async {}),
      isFalse,
    );
    expect(loaded, isFalse);
  });

  test('loads and replays the configured fixture once', () async {
    final subject = bootstrap();
    var loads = 0;
    Map<String, Object?>? replayed;

    Future<String> loadFixture(String path) async {
      loads += 1;
      expect(path, 'assets/debug/synthetic_pcm16_v1.json');
      return '{"schema_version":1,"fixture_id":"fixture"}';
    }

    Future<void> replay(Map<String, Object?> fixture) async {
      replayed = fixture;
    }

    expect(
      await subject.runOnce(loadFixture: loadFixture, replay: replay),
      isTrue,
    );
    expect(
      await subject.runOnce(loadFixture: loadFixture, replay: replay),
      isFalse,
    );
    expect(loads, 1);
    expect(replayed?['fixture_id'], 'fixture');
  });

  test('a failed attempt is not retried in the same process', () async {
    final subject = bootstrap();
    var loads = 0;

    Future<String> loadFixture(String _) async {
      loads += 1;
      return '[]';
    }

    await expectLater(
      subject.runOnce(loadFixture: loadFixture, replay: (_) async {}),
      throwsFormatException,
    );
    expect(subject.attempted, isTrue);
    expect(
      await subject.runOnce(loadFixture: loadFixture, replay: (_) async {}),
      isFalse,
    );
    expect(loads, 1);
  });
}
