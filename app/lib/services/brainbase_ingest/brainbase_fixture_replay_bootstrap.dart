import 'dart:convert';

import 'package:flutter/foundation.dart';

typedef BrainbaseFixtureLoader = Future<String> Function(String assetPath);
typedef BrainbaseFixtureReplay = Future<void> Function(
  Map<String, Object?> fixture,
);

/// Runs the bundled Brainbase audio fixture once per app process.
///
/// The production factory is intentionally guarded by three independent
/// conditions: a debug build and two explicit compile-time flags. Marking the
/// attempt before any I/O also prevents a malformed fixture or upload failure
/// from becoming a startup retry loop.
class BrainbaseFixtureReplayBootstrap {
  BrainbaseFixtureReplayBootstrap({
    required this.isDebugBuild,
    required this.isFixtureReplayEnabled,
    required this.isReplayOnStartEnabled,
    this.fixtureAsset = 'assets/debug/synthetic_pcm16_v1.json',
  });

  factory BrainbaseFixtureReplayBootstrap.fromEnvironment() {
    return BrainbaseFixtureReplayBootstrap(
      isDebugBuild: kDebugMode,
      isFixtureReplayEnabled: const bool.fromEnvironment(
        'OMI_FIXTURE_REPLAY_ENABLED',
      ),
      isReplayOnStartEnabled: const bool.fromEnvironment(
        'OMI_FIXTURE_REPLAY_ON_START',
      ),
    );
  }

  final bool isDebugBuild;
  final bool isFixtureReplayEnabled;
  final bool isReplayOnStartEnabled;
  final String fixtureAsset;

  bool _attempted = false;

  bool get attempted => _attempted;

  Future<bool> runOnce({
    required BrainbaseFixtureLoader loadFixture,
    required BrainbaseFixtureReplay replay,
  }) async {
    if (!isDebugBuild || !isFixtureReplayEnabled || !isReplayOnStartEnabled || _attempted) {
      return false;
    }

    _attempted = true;
    final decoded = jsonDecode(await loadFixture(fixtureAsset));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Brainbase replay fixture must be a JSON object',
      );
    }
    await replay(Map<String, Object?>.from(decoded));
    return true;
  }
}
