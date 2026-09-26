import 'dart:io';

import 'package:omi/services/brainbase_ingest/brainbase_offline_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omi/backend/http/api/conversations.dart';

class _UploadClient implements BrainbaseOfflineSync {
  _UploadClient({this.error});
  final BrainbaseOfflineSyncException? error;

  @override
  Future<String> upload(List<File> files, {BrainbaseOfflineUploadProgress? onProgress, String? conversationId}) async {
    if (error != null) throw error!;
    return 'session-1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const jobId = 'cloudflare:session-1';

  test('accepted Cloudflare upload enters namespaced queued reconciliation', () async {
    final result = await uploadLocalFilesV2(
      [File('audio_omi_opus_16000_1_fs160_1700000000.bin')],
      brainbaseClient: _UploadClient(),
    );
    expect(result.jobId, jobId);
  });

  test('Cloudflare capacity retry delay reaches the existing upload gate', () async {
    await expectLater(
      uploadLocalFilesV2(
        [File('audio_omi_opus_16000_1_fs160_1700000000.bin')],
        brainbaseClient:
            _UploadClient(error: BrainbaseOfflineSyncException('busy', statusCode: 429, retryAfterSeconds: 60)),
      ),
      throwsA(isA<SyncRateLimitedException>().having((error) => error.retryAfterSeconds, 'retry delay', 60)),
    );
  });

  test('canonical transcribed result acknowledges even silent audio', () {
    final result = mapBrainbaseSyncJobStatus(
      jobId,
      sessionId: 'session-1',
      status: 'transcribed',
      chunkCount: 1,
    );
    expect(result.outcome, SyncJobFetchOutcome.ok);
    expect(result.status!.isSuccess, isTrue);
    expect(result.status!.successfulSegments, 1);
  });

  for (final status in ['open', 'queued', 'transcribing', 'failed', 'unknown', 'completed']) {
    test('$status cannot acknowledge or re-arm an existing Cloudflare job', () {
      final result = mapBrainbaseSyncJobStatus(
        jobId,
        sessionId: 'session-1',
        status: status,
        chunkCount: 5,
      );
      expect(result.outcome, isNot(SyncJobFetchOutcome.notFound));
      expect(result.status?.isTerminal ?? false, isFalse);
    });
  }

  test('a mismatched response cannot acknowledge the requested job', () {
    final result = mapBrainbaseSyncJobStatus(
      jobId,
      sessionId: 'another-session',
      status: 'transcribed',
      chunkCount: 5,
    );
    expect(result.outcome, SyncJobFetchOutcome.transient);
  });
}
