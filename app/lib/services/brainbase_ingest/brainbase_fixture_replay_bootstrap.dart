import 'dart:convert';

import 'package:flutter/foundation.dart';

typedef BrainbaseFixtureLoader = Future<String> Function(String assetPath);
typedef BrainbaseFixtureReplay = Future<void> Function(
  Map<String, Object?> fixture,
);

/// Runs the bundled Brainbase audio fixture once per app process.
///
/// The production factory is intentionally guarded by three independent
/// conditions: an explicitly eligible build and two explicit compile-time
/// flags. Normal release builds remain ineligible; the personal E2E build can
/// opt in without requiring an attached Flutter debugger. Concurrent runs and
/// repeat successful submissions are suppressed, while a transient load or
/// upload failure remains eligible for a bounded retry by the launcher.
class BrainbaseFixtureReplayBootstrap {
  BrainbaseFixtureReplayBootstrap({
    required this.isReplayBuild,
    required this.isFixtureReplayEnabled,
    required this.isReplayOnStartEnabled,
    this.fixtureAsset = 'assets/debug/synthetic_pcm16_v1.json',
  });

  factory BrainbaseFixtureReplayBootstrap.fromEnvironment() {
    return BrainbaseFixtureReplayBootstrap(
      isReplayBuild: kDebugMode || const bool.fromEnvironment('OMI_PERSONAL_E2E_BUILD'),
      isFixtureReplayEnabled: const bool.fromEnvironment(
        'OMI_FIXTURE_REPLAY_ENABLED',
      ),
      isReplayOnStartEnabled: const bool.fromEnvironment(
        'OMI_FIXTURE_REPLAY_ON_START',
      ),
    );
  }

  final bool isReplayBuild;
  final bool isFixtureReplayEnabled;
  final bool isReplayOnStartEnabled;
  final String fixtureAsset;

  bool _attempted = false;
  bool _running = false;

  bool get attempted => _attempted;

  Future<bool> runOnce({
    required BrainbaseFixtureLoader loadFixture,
    required BrainbaseFixtureReplay replay,
  }) async {
    if (!isReplayBuild || !isFixtureReplayEnabled || !isReplayOnStartEnabled || _attempted || _running) {
      return false;
    }

    _running = true;
    try {
      final decoded = jsonDecode(await loadFixture(fixtureAsset));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Brainbase replay fixture must be a JSON object',
        );
      }
      await replay(Map<String, Object?>.from(decoded));
      _attempted = true;
      return true;
    } finally {
      _running = false;
    }
  }
}
