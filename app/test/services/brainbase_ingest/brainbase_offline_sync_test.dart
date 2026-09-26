import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omi/services/brainbase_ingest/brainbase_offline_sync.dart';

void main() {
  test('creates a session with recording metadata and uploads a WAV chunk', () async {
    final directory = await Directory.systemTemp.createTemp('brainbase_offline_sync_');
    addTearDown(() => directory.delete(recursive: true));
    final file = await _writePcmWal(directory, timestampMilliseconds: 1700000000000);
    final requests = <http.BaseRequest>[];
    Map<String, dynamic>? createBody;
    var putBytes = <int>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST' && request.url.path == '/v1/upload-sessions') {
        createBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({'sessionId': 'session-1'}, statusCode: 201);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/presign')) {
        return _json({'putUrl': 'https://r2.test/chunk', 'alreadyUploaded': false});
      }
      if (request.method == 'PUT' && request.url.host == 'r2.test') {
        putBytes = request.bodyBytes;
        return http.Response('', 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/complete')) {
        return _json({'ok': true});
      }
      if (request.method == 'POST' && request.url.path.endsWith('/finalize')) {
        return _json({'ok': true, 'queued': true, 'chunkCount': 1});
      }
      throw StateError('unexpected ${request.method} ${request.url}');
    });

    final progress = <List<num>>[];
    final sync = BrainbaseOfflineSync(
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
      journalDirectory: directory,
    );
    final sessionId = await sync.upload(
      [file],
      conversationId: 'conversation-7',
      onProgress: (sent, total, speed) => progress.add([sent, total, speed]),
    );

    expect(sessionId, 'session-1');
    expect(createBody?['deviceId'], 'fixture');
    expect(createBody?['sourceCodec'], 'pcm16');
    expect(createBody?['sampleRate'], 16000);
    expect(createBody?['channels'], 1);
    expect(createBody?['sourceConversationId'], 'conversation-7');
    expect(createBody?['recordedAt'], '2023-11-14T22:13:20.000Z');
    expect(createBody?['chunkDurationSeconds'], 5);
    expect(putBytes.take(4).toList(), [82, 73, 70, 70]); // RIFF
    expect(progress, hasLength(1));
    expect(progress.single[0], progress.single[1]);
    expect(requests.where((request) => request.url.path == '/v1/upload-sessions').length, 1);
  });

  test('keeps the journal and retries finalization after an acknowledgement loss', () async {
    final directory = await Directory.systemTemp.createTemp('brainbase_offline_retry_');
    addTearDown(() => directory.delete(recursive: true));
    final file = await _writePcmWal(directory, timestampMilliseconds: 1700000000000);
    var finalizeCalls = 0;
    var getCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path == '/v1/upload-sessions') {
        return _json({'sessionId': 'session-retry'}, statusCode: 201);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/presign')) {
        return _json({'putUrl': 'https://r2.test/chunk', 'alreadyUploaded': false});
      }
      if (request.method == 'PUT') return http.Response('', 200);
      if (request.method == 'POST' && request.url.path.endsWith('/complete')) {
        return _json({'ok': true});
      }
      if (request.method == 'POST' && request.url.path.endsWith('/finalize')) {
        finalizeCalls++;
        if (finalizeCalls == 1) return http.Response('temporarily unavailable', 503);
        return _json({'ok': true, 'queued': true});
      }
      if (request.method == 'GET' && request.url.path.endsWith('/session-retry')) {
        getCalls++;
        return _json({
          'session': {
            'id': 'session-retry',
            'status': 'open',
            'chunk_count': 1,
          },
          'chunks': const <dynamic>[],
        });
      }
      throw StateError('unexpected ${request.method} ${request.url}');
    });
    final sync = BrainbaseOfflineSync(
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
      journalDirectory: directory,
    );

    await expectLater(
        sync.upload([file]), throwsA(isA<BrainbaseOfflineSyncException>().having((e) => e.statusCode, 'status', 503)));
    final journal = jsonDecode(await File('${directory.path}/journal.json').readAsString()) as Map<String, dynamic>;
    expect((journal['batches'] as Map<String, dynamic>).values.single['sessionId'], 'session-retry');

    expect(await sync.upload([file]), 'session-retry');
    expect(finalizeCalls, 2);
    expect(getCalls, 1);
  });

  test('does not presign a closed session when resuming', () async {
    final directory = await Directory.systemTemp.createTemp('brainbase_offline_closed_');
    addTearDown(() => directory.delete(recursive: true));
    final file = await _writePcmWal(directory, timestampMilliseconds: 1700000000000);
    final seed = File('${directory.path}/journal.json');
    await seed.writeAsString(jsonEncode({
      'version': 1,
      'batches': {
        // This key is replaced below after the first client computes it.
      },
    }));

    var presignCalls = 0;
    var finalizeCalls = 0;
    var getCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path == '/v1/upload-sessions') {
        return _json({'sessionId': 'session-closed'}, statusCode: 201);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/presign')) {
        presignCalls++;
        return _json({'putUrl': 'https://r2.test/chunk', 'alreadyUploaded': false});
      }
      if (request.method == 'PUT') return http.Response('', 200);
      if (request.method == 'POST' && request.url.path.endsWith('/complete')) return _json({'ok': true});
      if (request.method == 'POST' && request.url.path.endsWith('/finalize')) {
        finalizeCalls++;
        return _json({'ok': true, 'queued': true});
      }
      if (request.method == 'GET' && request.url.path.endsWith('/session-closed')) {
        getCalls++;
        return _json({
          'session': {'id': 'session-closed', 'status': 'queued', 'chunk_count': 1},
          'chunks': const <dynamic>[],
        });
      }
      throw StateError('unexpected ${request.method} ${request.url}');
    });
    final sync = BrainbaseOfflineSync(
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
      journalDirectory: directory,
    );
    // Seed the journal through a normal upload, then reopen with a queued
    // status. This also exercises the stable batch hash used for retries.
    await sync.upload([file]);
    final journal = jsonDecode(await seed.readAsString()) as Map<String, dynamic>;
    final batches = journal['batches'] as Map<String, dynamic>;
    expect(batches.values.single['sessionId'], 'session-closed');
    expect(presignCalls, 1);
    expect(finalizeCalls, 1);

    final resumed = BrainbaseOfflineSync(
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
      journalDirectory: directory,
    );
    expect(await resumed.upload([file]), 'session-closed');
    expect(getCalls, 1);
    expect(presignCalls, 1);
    expect(finalizeCalls, 2);
  });

  test('fetchStatus preserves an empty transcript and strips the legacy prefix', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/transcript-sessions/session-1');
      return _json({
        'session': {
          'id': 'session-1',
          'status': 'transcribed',
          'recorded_at': '2026-09-26T12:00:00.000Z',
          'source_conversation_id': 'conversation-1',
          'chunk_count': 2,
        },
        'chunks': [
          {'sequence': 1, 'text': ''},
          {'sequence': 0, 'text': ''},
        ],
      });
    });
    final sync = BrainbaseOfflineSync(
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
    );

    final status = await sync.fetchStatus('cloudflare:session-1');

    expect(status.isTranscribed, isTrue);
    expect(status.transcript, isEmpty);
    expect(status.chunkCount, 2);
    expect(status.conversationId, 'conversation-1');
    expect(status.recordedAt, DateTime.parse('2026-09-26T12:00:00.000Z'));
  });

  test('rejects a transcript response for a different session id', () async {
    final client = MockClient((request) async {
      return _json({
        'session': {'id': 'other-session', 'status': 'transcribed'},
        'chunks': const <dynamic>[],
      });
    });
    final sync = BrainbaseOfflineSync(
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
    );

    await expectLater(
      sync.fetchStatus('session-1'),
      throwsA(isA<BrainbaseOfflineSyncException>()),
    );
  });

  test('fromEnvironment is disabled when defines are absent', () {
    expect(BrainbaseOfflineSync.fromEnvironment(), isNull);
  });

  test('fromEnvironment rejects every non-local profile', () {
    const profile = String.fromEnvironment('OMI_APP_PROFILE');
    if (profile.isNotEmpty && profile != 'local_dev') {
      expect(BrainbaseOfflineSync.fromEnvironment(), isNull);
    }
  });
}

Future<File> _writePcmWal(
  Directory directory, {
  required int timestampMilliseconds,
}) async {
  final payload = Uint8List(320); // 160 mono 16-bit samples
  final bytes = BytesBuilder()
    ..add(Uint8List.fromList([payload.length & 0xff, (payload.length >> 8) & 0xff, 0, 0]))
    ..add(payload);
  final file = File('${directory.path}/audio_fixture_pcm16_16000_1_fs160_$timestampMilliseconds.bin');
  await file.writeAsBytes(bytes.takeBytes());
  return file;
}

http.Response _json(Object body, {int statusCode = 200}) => http.Response(
      jsonEncode(body),
      statusCode,
      headers: const {'content-type': 'application/json'},
    );
