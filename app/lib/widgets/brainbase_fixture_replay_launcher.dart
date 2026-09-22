import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omi/providers/capture_provider.dart';
import 'package:omi/services/brainbase_ingest/brainbase_fixture_replay_bootstrap.dart';
import 'package:omi/utils/logger.dart';
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
    for (final delay in _retryDelays) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (!mounted) return;
      try {
        final replayed = await _bootstrap.runOnce(
          loadFixture: rootBundle.loadString,
          replay: context.read<CaptureProvider>().replayBrainbaseFixtureForDebug,
        );
        if (replayed) {
          Logger.debug(
            'Brainbase fixture replay submitted through the capture pipeline',
          );
        }
        return;
      } catch (error, stack) {
        Logger.error('Brainbase fixture replay failed: $error\n$stack');
      }
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
