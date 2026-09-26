import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omi/backend/preferences.dart';
import 'package:omi/backend/schema/conversation.dart';
import 'package:omi/models/sync_state.dart';
import 'package:omi/providers/sync_provider.dart';
import 'package:omi/services/wals.dart';

class _FakeSyncs {
  FlashSyncStallReason flashStallReason = FlashSyncStallReason.none;

  Future<List<Wal>> getAllWals() async => [];

  Future<SyncLocalFilesResponse?> syncAll({IWalSyncProgressListener? progress}) async {
    progress?.onWalSyncedProgress(
      0.1,
      phase: SyncPhase.uploadingToCloud,
      currentFile: 1,
      totalFiles: 404,
      uploadedBytes: 100,
      totalBytesToUpload: 1000,
    );
    progress?.onWalSyncedProgress(0.42, phase: SyncPhase.downloadingFromDevice);
    progress?.onWalSyncedProgress(0.0, phase: SyncPhase.uploadingToCloud);
    progress?.onWalSyncedProgress(0.2, phase: SyncPhase.uploadingToCloud, currentFile: 2, totalFiles: 404);
    return null;
  }
}

class _FakeWalService implements IWalService {
  final _FakeSyncs syncs = _FakeSyncs();

  @override
  void start() {}

  @override
  Future<void> stop() async {}

  @override
  void subscribe(IWalServiceListener subscription, Object context) {}

  @override
  void unsubscribe(Object context) {}

  @override
  dynamic getSyncs() => syncs;
}

SyncUploadGate _hermeticGate() {
  final limiter = SyncRateLimiter.instance;
  limiter.clear();
  return SyncUploadGate(
    limiter: limiter,
    fairUseStatusLoader: () async => {'stage': 'none'},
    uploader: (files, {onUploadProgress, conversationId, claimLiveCapture = false, geolocation}) async =>
        UploadFilesResult.queued('unused'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesUtil.init();
    SyncRateLimiter.instance.clear();
  });

  test('sync phases do not inherit file or byte counters from a previous phase', () async {
    final provider = SyncProvider(
      walService: _FakeWalService(),
      uploadGate: _hermeticGate(),
      startBackgroundSync: false,
    );
    final states = <SyncState>[];
    provider.addListener(() => states.add(provider.syncState));

    await provider.initialized;
    await provider.syncWals();

    final deviceState = states.lastWhere(
      (state) => state.phase == SyncPhase.downloadingFromDevice && state.progress == 0.42,
    );
    expect(deviceState.currentFile, 0);
    expect(deviceState.totalFiles, 0);
    expect(deviceState.uploadedBytes, isNull);
    expect(deviceState.totalBytesToUpload, isNull);

    final freshUploadState = states.lastWhere(
      (state) => state.phase == SyncPhase.uploadingToCloud && state.progress == 0.0,
    );
    expect(freshUploadState.currentFile, 0);
    expect(freshUploadState.totalFiles, 0);

    final resumedUploadState = states.lastWhere(
      (state) => state.phase == SyncPhase.uploadingToCloud && state.progress == 0.2,
    );
    expect(resumedUploadState.currentFile, 2);
    expect(resumedUploadState.totalFiles, 404);

    provider.dispose();
  });
}
