import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omi/providers/capture_provider.dart';
import 'package:omi/services/brainbase_ingest/brainbase_fixture_replay_bootstrap.dart';
import 'package:omi/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

/// Opt-in debug launcher for deterministic audio-to-Cloudflare verification.
class BrainbaseFixtureReplayLauncher extends StatefulWidget {
  const BrainbaseFixtureReplayLauncher({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<BrainbaseFixtureReplayLauncher> createState() => _BrainbaseFixtureReplayLauncherState();
}

class _BrainbaseFixtureReplayLauncherState extends State<BrainbaseFixtureReplayLauncher> {
  static const _retryDelays = <Duration>[
    Duration.zero,
    Duration(seconds: 2),
    Duration(seconds: 5),
  ];

  final BrainbaseFixtureReplayBootstrap _bootstrap = BrainbaseFixtureReplayBootstrap.fromEnvironment();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_replayWithRetry());
    });
  }

  Future<void> _replayWithRetry() async {
    await _writeStatus('launcher_started');
    for (final delay in _retryDelays) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (!mounted) return;
      try {
        await _writeStatus('replay_attempt');
        if (!mounted) return;
        final replayed = await _bootstrap.runOnce(
          loadFixture: rootBundle.loadString,
          replay: context.read<CaptureProvider>().replayBrainbaseFixtureForDebug,
        );
        if (replayed) {
          await _writeStatus('replay_completed');
          Logger.debug(
            'Brainbase fixture replay submitted through the capture pipeline',
          );
        } else {
          await _writeStatus('replay_ineligible');
        }
        return;
      } catch (error, stack) {
        await _writeStatus(
          'replay_failed',
          errorType: error.runtimeType.toString(),
          errorMessage: error.toString(),
        );
        Logger.error('Brainbase fixture replay failed: $error\n$stack');
      }
    }
  }

  Future<void> _writeStatus(
    String state, {
    String? errorType,
    String? errorMessage,
  }) async {
    if (!_bootstrap.isReplayBuild && !_bootstrap.isFixtureReplayEnabled && !_bootstrap.isReplayOnStartEnabled) {
      return;
    }
    try {
      final support = await getApplicationSupportDirectory();
      final status = File('${support.path}/brainbase_fixture_replay_status.json');
      await status.writeAsString(
        jsonEncode({
          'state': state,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'is_replay_build': _bootstrap.isReplayBuild,
          'is_fixture_replay_enabled': _bootstrap.isFixtureReplayEnabled,
          'is_replay_on_start_enabled': _bootstrap.isReplayOnStartEnabled,
          if (errorType != null) 'error_type': errorType,
          if (errorMessage != null) 'error_message': errorMessage,
        }),
        flush: true,
      );
    } catch (error, stack) {
      Logger.error('Brainbase fixture replay status write failed: $error\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Readback stays in the normal Omi navigation. The production provider
    // selects Cloudflare while the existing list and detail pages remain the
    // UI authority.
    return widget.child;
  }
}
