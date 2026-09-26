import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omi/backend/http/api/conversations.dart';
import 'package:omi/backend/preferences.dart';
import 'package:omi/backend/schema/bt_device/bt_device.dart';
import 'package:omi/backend/schema/conversation.dart';
import 'package:omi/services/brainbase_ingest/brainbase_offline_sync.dart';
import 'package:omi/services/wals/local_wal_sync.dart';
import 'package:omi/services/wals/wal.dart';
import 'package:omi/services/wals/wal_interfaces.dart';
import 'package:omi/utils/wal_file_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnavailableCloudflare implements BrainbaseOfflineSync {
  _UnavailableCloudflare(this.httpStatus);
  final int httpStatus;

  @override
  Future<BrainbaseOfflineStatus> fetchStatus(String sessionId) async => throw HttpException('HTTP $httpStatus');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Listener implements IWalSyncListener {
  @override
  void onWalUpdated() {}
  @override
  void onWalSynced(Wal wal, {ServerConversation? conversation}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesUtil.init();
    directory = await Directory.systemTemp.createTemp('cloudflare_wal_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory' ? directory.path : null,
    );
    await WalFileManager.init();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await directory.delete(recursive: true);
  });

  for (final code in [401, 403, 404, 429, 500]) {
    test('Cloudflare $code retains uploaded WAL, job and original audio', () async {
      final file = File('${directory.path}/audio_omi_opus_16000_1_fs160_1700000000.bin');
      await file.writeAsBytes([1, 2, 3, 4]);
      final wal = Wal(
        timerStart: 1700000000,
        codec: BleAudioCodec.opus,
        seconds: 31,
        status: WalStatus.uploaded,
        storage: WalStorage.disk,
        device: 'omi',
        filePath: file.path,
      )..jobId = 'cloudflare:existing-session';
      final sync = LocalWalSyncImpl(
        _Listener(),
        jobStatusFetcher: (id) => fetchSyncJobStatus(id, brainbaseClient: _UnavailableCloudflare(code)),
      )..testWals = [wal];

      await sync.reconcileUploadedWals();

      expect(wal.status, WalStatus.uploaded);
      expect(wal.jobId, 'cloudflare:existing-session');
      expect(wal.retryCount, 0);
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
    });
  }

  test('all retained members become synced after canonical transcription acknowledgement', () async {
    final wals = List.generate(
        5,
        (index) => Wal(
              timerStart: 1700000000 + index * 60,
              codec: BleAudioCodec.opus,
              seconds: 60,
              status: WalStatus.uploaded,
              storage: WalStorage.disk,
              device: 'omi',
            )..jobId = 'cloudflare:existing-session');
    final sync = LocalWalSyncImpl(
      _Listener(),
      jobStatusFetcher: (id) async => mapBrainbaseSyncJobStatus(
        id,
        sessionId: 'existing-session',
        status: 'transcribed',
        chunkCount: 5,
      ),
    )..testWals = wals;

    await sync.reconcileUploadedWals();

    expect(wals.map((wal) => wal.status), everyElement(WalStatus.synced));
    expect(wals.map((wal) => wal.jobId), everyElement(isNull));
  });
}
