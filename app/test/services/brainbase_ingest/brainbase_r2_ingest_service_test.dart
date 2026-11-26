import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omi/backend/schema/bt_device/bt_device.dart';
import 'package:omi/services/brainbase_ingest/brainbase_r2_ingest_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startup recovery is a no-op when Brainbase ingest is disabled', () async {
    await BrainbaseR2IngestService.instance.resumePendingUploads();
  });

  test(
    'keeps a chunk and finalize intent until a failed upload can retry',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'brainbase_r2_queue_test_',
      );
      addTearDown(() => directory.delete(recursive: true));

      var putAttempts = 0;
      var completeCalls = 0;
      var finalizeCalls = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/presign')) {
          return http.Response(
            jsonEncode({
              'putUrl': 'https://upload.test/chunk',
              'alreadyUploaded': false,
            }),
            200,
          );
        }
        if (request.method == 'PUT' && request.url.host == 'upload.test') {
          putAttempts++;
          return http.Response('', putAttempts == 1 ? 503 : 200);
        }
        if (request.method == 'POST' && request.url.path.endsWith('/complete')) {
          completeCalls++;
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        if (request.method == 'POST' && request.url.path.endsWith('/finalize')) {
          finalizeCalls++;
          return http.Response(jsonEncode({'queued': true}), 200);
        }
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
      });

      var queue = await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
      );
      await queue.markSessionActive('session-1');
      await queue.enqueue(
        sessionId: 'session-1',
        sequence: 0,
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      await queue.markForFinalize('session-1');

      final manifest = jsonDecode(
        await File('${directory.path}/manifest.json').readAsString(),
      ) as Map<String, dynamic>;
      expect(
        (manifest['items'] as List<dynamic>).single['path'],
        'session-1_00000000.wav',
      );

      await queue.drain();

      expect(putAttempts, 1);
      expect(queue.pendingItemCount, 1);
      expect(queue.isFinalizePending('session-1'), isTrue);
      expect(completeCalls, 0);
      expect(finalizeCalls, 0);

      queue = await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
      );
      await queue.drain();

      expect(putAttempts, 2);
      expect(queue.pendingItemCount, 0);
      expect(queue.isFinalizePending('session-1'), isFalse);
      expect(completeCalls, 1);
      expect(finalizeCalls, 1);
      expect(
        directory.listSync().whereType<File>().map((file) => file.path),
        everyElement(endsWith('manifest.json')),
      );
    },
  );

  for (final hasAudio in [true, false]) {
    test('recovers a fully uploaded session after restart: audio=$hasAudio', () async {
      final directory = await Directory.systemTemp.createTemp('r2_restart_');
      addTearDown(() => directory.delete(recursive: true));
      final events = <String>[];
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/presign')) {
          return http.Response(jsonEncode({'putUrl': 'https://upload.test/chunk', 'alreadyUploaded': false}), 200);
        }
        if (request.method == 'PUT') return http.Response('', 200);
        if (request.url.path.endsWith('/complete')) {
          events.add('complete');
          return http.Response('{}', 200);
        }
        if (request.url.path.endsWith('/finalize')) {
          events.add(request.url.path.contains('old-session') ? 'old-finalize' : 'new-finalize');
          return http.Response('{}', !hasAudio && request.url.path.contains('old-session') ? 409 : 200);
        }
        throw StateError('Unexpected request: ${request.url}');
      });
      Future<BrainbaseR2UploadQueue> reopen() => BrainbaseR2UploadQueue.openAt(
          directory: directory, baseUrl: 'https://ingest.test', token: 'test-token', client: client);
      var queue = await reopen();
      await queue.markSessionActive('old-session');
      if (hasAudio) {
        await queue.enqueue(sessionId: 'old-session', sequence: 0, bytes: Uint8List.fromList([1, 2, 3]));
      }
      await queue.drain();
      expect(queue.pendingItemCount, 0);
      expect(events, hasAudio ? ['complete'] : isEmpty);
      queue = await reopen();
      expect(queue.isFinalizePending('old-session'), hasAudio);
      await queue.drain();
      expect(events, hasAudio ? ['complete', 'old-finalize'] : isEmpty);
      await queue.markSessionActive('new-session');
      await queue.drain();
      expect(events.where((event) => event == 'new-finalize'), isEmpty);
      await queue.enqueue(sessionId: 'new-session', sequence: 0, bytes: Uint8List.fromList([4, 5, 6]));
      await queue.drain();
      await queue.markForFinalize('new-session');
      await queue.drain();
      expect(events.last, 'new-finalize');
      expect(queue.isFinalizePending('new-session'), isFalse);
    });
  }

  test('recovers an active marker when the queue is reopened', () async {
    final directory = await Directory.systemTemp.createTemp(
      'brainbase_r2_active_marker_test_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final bytes = Uint8List.fromList([16, 17, 18]);
    final file = File('${directory.path}/session-active_00000000.wav');
    await file.writeAsBytes(bytes, flush: true);
    await File('${directory.path}/manifest.json').writeAsString(
      jsonEncode({
        'items': [
          {
            'sessionId': 'session-active',
            'sequence': 0,
            'path': 'session-active_00000000.wav',
            'sha256': sha256.convert(bytes).toString(),
            'byteLength': bytes.length,
          },
        ],
        'finalizeSessions': [],
        'activeSessionId': 'session-active',
        'activeSessionHasChunks': true,
      }),
    );

    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/presign')) {
        return http.Response(
          jsonEncode({
            'putUrl': 'https://upload.test/active',
            'alreadyUploaded': false,
          }),
          200,
        );
      }
      if (request.method == 'PUT' && request.url.host == 'upload.test') {
        return http.Response('', 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/complete')) {
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/finalize')) {
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      throw StateError(
        'Unexpected request: ${request.method} ${request.url}',
      );
    });

    final queue = await BrainbaseR2UploadQueue.openAt(
      directory: directory,
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
    );

    expect(queue.isFinalizePending('session-active'), isTrue);

    await queue.drain();

    expect(queue.pendingItemCount, 0);
    expect(queue.isFinalizePending('session-active'), isFalse);
    expect(await file.exists(), isFalse);
  });

  test(
    'recovers legacy item-only sessions and keeps failures retryable',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'brainbase_r2_legacy_session_recovery_test_',
      );
      addTearDown(() => directory.delete(recursive: true));

      final bytes = Uint8List.fromList([19, 20, 21]);
      final file = File('${directory.path}/session-legacy_00000000.wav');
      await file.writeAsBytes(bytes, flush: true);
      await File('${directory.path}/manifest.json').writeAsString(
        jsonEncode({
          'items': [
            {
              'sessionId': 'session-legacy',
              'sequence': 0,
              'path': 'session-legacy_00000000.wav',
              'sha256': sha256.convert(bytes).toString(),
              'byteLength': bytes.length,
            },
          ],
          'finalizeSessions': [],
        }),
      );

      var putAttempts = 0;
      var completeCalls = 0;
      var finalizeCalls = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/presign')) {
          return http.Response(
            jsonEncode({
              'putUrl': 'https://upload.test/legacy',
              'alreadyUploaded': false,
            }),
            200,
          );
        }
        if (request.method == 'PUT' && request.url.host == 'upload.test') {
          putAttempts++;
          return http.Response('', putAttempts == 1 ? 503 : 200);
        }
        if (request.method == 'POST' && request.url.path.endsWith('/complete')) {
          completeCalls++;
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        if (request.method == 'POST' && request.url.path.endsWith('/finalize')) {
          finalizeCalls++;
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
      });

      var queue = await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
      );
      expect(queue.isFinalizePending('session-legacy'), isTrue);

      await queue.drain();

      expect(putAttempts, 1);
      expect(completeCalls, 0);
      expect(finalizeCalls, 0);
      expect(queue.pendingItemCount, 1);
      expect(await file.exists(), isTrue);
      expect(queue.isFinalizePending('session-legacy'), isTrue);

      queue = await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
      );
      await queue.drain();

      expect(putAttempts, 2);
      expect(completeCalls, 1);
      expect(finalizeCalls, 1);
      expect(queue.pendingItemCount, 0);
      expect(queue.isFinalizePending('session-legacy'), isFalse);
      expect(await file.exists(), isFalse);
    },
  );

  test('persists a finalize intent when finalization fails', () async {
    final directory = await Directory.systemTemp.createTemp(
      'brainbase_r2_finalize_retry_test_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final bytes = Uint8List.fromList([22, 23, 24]);
    final file = File('${directory.path}/session-finalize_00000000.wav');
    await file.writeAsBytes(bytes, flush: true);
    await File('${directory.path}/manifest.json').writeAsString(
      jsonEncode({
        'items': [
          {
            'sessionId': 'session-finalize',
            'sequence': 0,
            'path': 'session-finalize_00000000.wav',
            'sha256': sha256.convert(bytes).toString(),
            'byteLength': bytes.length,
          },
        ],
        'finalizeSessions': ['session-finalize'],
      }),
    );

    var finalizeAttempts = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/presign')) {
        return http.Response(
          jsonEncode({
            'putUrl': 'https://upload.test/finalize',
            'alreadyUploaded': false,
          }),
          200,
        );
      }
      if (request.method == 'PUT' && request.url.host == 'upload.test') {
        return http.Response('', 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/complete')) {
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/finalize')) {
        finalizeAttempts++;
        return finalizeAttempts == 1
            ? http.Response(jsonEncode({'error': 'temporary'}), 503)
            : http.Response(jsonEncode({'ok': true}), 200);
      }
      throw StateError(
        'Unexpected request: ${request.method} ${request.url}',
      );
    });

    var queue = await BrainbaseR2UploadQueue.openAt(
      directory: directory,
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
    );
    await queue.drain();

    expect(queue.pendingItemCount, 0);
    expect(await file.exists(), isFalse);
    expect(queue.isFinalizePending('session-finalize'), isTrue);
    final failedManifest = jsonDecode(
      await File('${directory.path}/manifest.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(failedManifest['finalizeSessions'], ['session-finalize']);

    queue = await BrainbaseR2UploadQueue.openAt(
      directory: directory,
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
    );
    await queue.drain();

    expect(finalizeAttempts, 2);
    expect(queue.isFinalizePending('session-finalize'), isFalse);
  });

  test('does not finalize an active session before it is stopped', () async {
    final directory = await Directory.systemTemp.createTemp(
      'brainbase_r2_active_session_test_',
    );
    addTearDown(() => directory.delete(recursive: true));

    var finalizeCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/finalize')) {
        finalizeCalls++;
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      throw StateError(
        'Unexpected request: ${request.method} ${request.url}',
      );
    });

    final queue = await BrainbaseR2UploadQueue.openAt(
      directory: directory,
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
    );
    await queue.markSessionActive('session-current');

    final activeManifest = jsonDecode(
      await File('${directory.path}/manifest.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(activeManifest['activeSessionId'], 'session-current');
    expect(activeManifest['finalizeSessions'], isEmpty);

    await queue.drain();

    expect(finalizeCalls, 0);
    expect(queue.isFinalizePending('session-current'), isFalse);

    await queue.markForFinalize('session-current');
    final stoppedManifest = jsonDecode(
      await File('${directory.path}/manifest.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(stoppedManifest['activeSessionId'], isNull);
    expect(stoppedManifest['activeSessionHasChunks'], false);
    expect(stoppedManifest['finalizeSessions'], isEmpty);

    await queue.drain();

    expect(finalizeCalls, 0);
    expect(queue.isFinalizePending('session-current'), isFalse);
  });

  test('drains a relative manifest item from the current queue directory', () async {
    final directory = await Directory.systemTemp.createTemp(
      'brainbase_r2_relative_manifest_test_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final bytes = Uint8List.fromList([4, 5, 6]);
    final file = File('${directory.path}/relative.wav');
    await file.writeAsBytes(bytes, flush: true);
    await File('${directory.path}/manifest.json').writeAsString(
      jsonEncode({
        'items': [
          {
            'sessionId': 'session-relative',
            'sequence': 0,
            'path': 'relative.wav',
            'sha256': sha256.convert(bytes).toString(),
            'byteLength': bytes.length,
          },
        ],
        'finalizeSessions': [],
      }),
    );

    final uploaded = <List<int>>[];
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/presign')) {
        return http.Response(
          jsonEncode({
            'putUrl': 'https://upload.test/relative',
            'alreadyUploaded': false,
          }),
          200,
        );
      }
      if (request.method == 'PUT' && request.url.host == 'upload.test') {
        uploaded.add(request.bodyBytes);
        return http.Response('', 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/complete')) {
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/finalize')) {
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      throw StateError(
        'Unexpected request: ${request.method} ${request.url}',
      );
    });

    final queue = await BrainbaseR2UploadQueue.openAt(
      directory: directory,
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
    );
    await queue.drain();

    expect(uploaded, [bytes]);
    expect(await file.exists(), isFalse);
    expect(queue.pendingItemCount, 0);
    expect(queue.isFinalizePending('session-relative'), isFalse);
  });

  test('resolves a legacy absolute path inside the current queue directory', () async {
    final directory = await Directory.systemTemp.createTemp(
      'brainbase_r2_legacy_manifest_test_',
    );
    final oldContainer = await Directory.systemTemp.createTemp(
      'brainbase_r2_old_container_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    addTearDown(() => oldContainer.delete(recursive: true));

    final currentBytes = Uint8List.fromList([7, 8, 9]);
    final oldBytes = Uint8List.fromList([0, 0, 0]);
    final currentFile = File('${directory.path}/moved.wav');
    final oldFile = File(
      '${oldContainer.path}/Library/Application Support/brainbase_r2_ingest/moved.wav',
    );
    await currentFile.writeAsBytes(currentBytes, flush: true);
    await oldFile.parent.create(recursive: true);
    await oldFile.writeAsBytes(oldBytes, flush: true);
    await File('${directory.path}/manifest.json').writeAsString(
      jsonEncode({
        'items': [
          {
            'sessionId': 'session-moved',
            'sequence': 1,
            'path': oldFile.path,
            'sha256': sha256.convert(currentBytes).toString(),
            'byteLength': currentBytes.length,
          },
        ],
        'finalizeSessions': [],
      }),
    );

    final uploaded = <List<int>>[];
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/presign')) {
        return http.Response(
          jsonEncode({
            'putUrl': 'https://upload.test/moved',
            'alreadyUploaded': false,
          }),
          200,
        );
      }
      if (request.method == 'PUT' && request.url.host == 'upload.test') {
        uploaded.add(request.bodyBytes);
        return http.Response('', 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/complete')) {
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/finalize')) {
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      throw StateError(
        'Unexpected request: ${request.method} ${request.url}',
      );
    });

    final queue = await BrainbaseR2UploadQueue.openAt(
      directory: directory,
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
    );
    await queue.drain();

    expect(uploaded, [currentBytes]);
    expect(await currentFile.exists(), isFalse);
    expect(await oldFile.exists(), isTrue);
    expect(await oldFile.readAsBytes(), oldBytes);
    expect(queue.pendingItemCount, 0);
    expect(queue.isFinalizePending('session-moved'), isFalse);
  });

  test('retains a queue item and rejects relative path traversal', () async {
    final root = await Directory.systemTemp.createTemp(
      'brainbase_r2_traversal_manifest_test_',
    );
    final directory = Directory('${root.path}/queue');
    await directory.create();
    addTearDown(() => root.delete(recursive: true));

    final outsideFile = File('${root.path}/escape.wav');
    final bytes = Uint8List.fromList([10, 11, 12]);
    await outsideFile.writeAsBytes(bytes, flush: true);
    await File('${directory.path}/manifest.json').writeAsString(
      jsonEncode({
        'items': [
          {
            'sessionId': 'session-traversal',
            'sequence': 0,
            'path': '../escape.wav',
            'sha256': sha256.convert(bytes).toString(),
            'byteLength': bytes.length,
          },
        ],
        'finalizeSessions': [],
      }),
    );

    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      throw StateError('unexpected request: ${request.method} ${request.url}');
    });

    final queue = await BrainbaseR2UploadQueue.openAt(
      directory: directory,
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
    );
    await queue.drain();

    expect(requestCount, 0);
    expect(queue.pendingItemCount, 1);
    expect(await outsideFile.exists(), isTrue);
  });

  test('retains a queue item and rejects a symlinked queue file', () async {
    final root = await Directory.systemTemp.createTemp(
      'brainbase_r2_symlink_manifest_test_',
    );
    final directory = Directory('${root.path}/queue');
    final outsideDirectory = Directory('${root.path}/outside');
    await directory.create();
    await outsideDirectory.create();
    addTearDown(() => root.delete(recursive: true));

    final bytes = Uint8List.fromList([13, 14, 15]);
    final outsideFile = File('${outsideDirectory.path}/source.wav');
    await outsideFile.writeAsBytes(bytes, flush: true);
    final link = Link('${directory.path}/linked.wav');
    await link.create(outsideFile.path);
    await File('${directory.path}/manifest.json').writeAsString(
      jsonEncode({
        'items': [
          {
            'sessionId': 'session-symlink',
            'sequence': 0,
            'path': 'linked.wav',
            'sha256': sha256.convert(bytes).toString(),
            'byteLength': bytes.length,
          },
        ],
        'finalizeSessions': [],
      }),
    );

    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      throw StateError('unexpected request: ${request.method} ${request.url}');
    });

    final queue = await BrainbaseR2UploadQueue.openAt(
      directory: directory,
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: client,
    );
    await queue.drain();

    expect(requestCount, 0);
    expect(queue.pendingItemCount, 1);
    expect(
      await FileSystemEntity.type(link.path, followLinks: false),
      FileSystemEntityType.link,
    );
    expect(await outsideFile.exists(), isTrue);
  });

  group('crash-safe drain (PR-04)', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('brainbase_r2_pr04_');
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    Map<String, dynamic> readManifest() =>
        jsonDecode(File('${directory.path}/manifest.json').readAsStringSync()) as Map<String, dynamic>;

    Future<void> writeManifest(List<Map<String, dynamic>> items, {List<String> finalize = const []}) {
      return File('${directory.path}/manifest.json').writeAsString(
        jsonEncode({'items': items, 'finalizeSessions': finalize}),
      );
    }

    Map<String, dynamic> itemFor(String sessionId, int sequence, Uint8List bytes) => {
          'sessionId': sessionId,
          'sequence': sequence,
          'path': '${sessionId}_${sequence.toString().padLeft(8, '0')}.wav',
          'sha256': sha256.convert(bytes).toString(),
          'byteLength': bytes.length,
        };

    test('saves the manifest without the item before deleting its audio', () async {
      var puts = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/presign')) {
          return http.Response(jsonEncode({'putUrl': 'https://upload.test/c', 'alreadyUploaded': false}), 200);
        }
        if (request.method == 'PUT') {
          puts++;
          return http.Response('', 200);
        }
        if (request.url.path.endsWith('/complete')) return http.Response('{}', 200);
        throw StateError('Unexpected request: ${request.method} ${request.url}');
      });
      Map<String, dynamic>? manifestAtDelete;
      var fileExistedAtDelete = false;
      final queue = await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
        beforeDeleteUploadedFile: (file) async {
          manifestAtDelete = readManifest();
          fileExistedAtDelete = await file.exists();
          // Simulate the process dying between the manifest save and delete.
          throw StateError('killed');
        },
      );
      await queue.enqueue(sessionId: 's', sequence: 0, bytes: Uint8List.fromList([1, 2, 3]));
      await queue.drain();

      expect(manifestAtDelete, isNotNull);
      expect(manifestAtDelete!['items'], isEmpty);
      expect(fileExistedAtDelete, isTrue);
      expect(File('${directory.path}/s_00000000.wav').existsSync(), isTrue);

      // The next start collects the orphan and never uploads it again.
      final reopened = await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
      );
      await reopened.drain();
      expect(File('${directory.path}/s_00000000.wav').existsSync(), isFalse);
      expect(reopened.pendingItemCount, 0);
      expect(puts, 1);
    });

    test('collects only unreferenced regular .wav files at open', () async {
      final kept = Uint8List.fromList([4, 5, 6]);
      await File('${directory.path}/keep_00000000.wav').writeAsBytes(kept);
      await File('${directory.path}/orphan_00000000.wav').writeAsBytes([7]);
      await File('${directory.path}/notes.txt').writeAsString('x');
      final outside = await Directory.systemTemp.createTemp('brainbase_r2_pr04_outside_');
      addTearDown(() => outside.delete(recursive: true));
      final target = File('${outside.path}/target.wav');
      await target.writeAsBytes([8]);
      await Link('${directory.path}/linked.wav').create(target.path);
      final subdirectory = await Directory('${directory.path}/sub.wav').create();
      await File('${subdirectory.path}/nested.wav').writeAsBytes([9]);
      await writeManifest([itemFor('keep', 0, kept)]);

      final client = MockClient((request) async => throw StateError('no network expected'));
      await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
      );

      expect(File('${directory.path}/keep_00000000.wav').existsSync(), isTrue);
      expect(File('${directory.path}/orphan_00000000.wav').existsSync(), isFalse);
      expect(File('${directory.path}/notes.txt').existsSync(), isTrue);
      expect(FileSystemEntity.typeSync('${directory.path}/linked.wav', followLinks: false), FileSystemEntityType.link);
      expect(target.existsSync(), isTrue);
      expect(File('${subdirectory.path}/nested.wav').existsSync(), isTrue);
      expect(File('${directory.path}/manifest.json').existsSync(), isTrue);
    });

    test('completes a missing chunk the server already holds', () async {
      final bytes = Uint8List.fromList([9, 9]);
      await writeManifest([itemFor('up', 0, bytes)], finalize: ['up']);
      final events = <String>[];
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/presign')) {
          events.add('presign');
          return http.Response(jsonEncode({'alreadyUploaded': true}), 200);
        }
        if (request.method == 'PUT') throw StateError('must not upload a missing file');
        if (request.url.path.endsWith('/complete')) {
          events.add('complete');
          return http.Response('{}', 200);
        }
        if (request.url.path.endsWith('/finalize')) {
          events.add('finalize');
          return http.Response('{}', 200);
        }
        throw StateError('Unexpected request: ${request.method} ${request.url}');
      });
      final queue = await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
      );
      await queue.drain();

      expect(events, ['presign', 'complete', 'finalize']);
      expect(queue.pendingItemCount, 0);
      expect(queue.corruptedItemCount, 0);
      expect(queue.isFinalizePending('up'), isFalse);
    });

    test('sets aside a lost chunk so later chunks still upload', () async {
      final lost = Uint8List.fromList([1]);
      final next = Uint8List.fromList([2, 2]);
      await File('${directory.path}/s_00000001.wav').writeAsBytes(next);
      await writeManifest([itemFor('s', 0, lost), itemFor('s', 1, next)], finalize: ['s']);
      final uploaded = <List<int>>[];
      final completed = <String>[];
      var finalized = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/presign')) {
          return http.Response(jsonEncode({'putUrl': 'https://upload.test/c', 'alreadyUploaded': false}), 200);
        }
        if (request.method == 'PUT') {
          uploaded.add(request.bodyBytes);
          return http.Response('', 200);
        }
        if (request.url.path.endsWith('/complete')) {
          completed.add(request.url.pathSegments[request.url.pathSegments.length - 2]);
          return http.Response('{}', 200);
        }
        if (request.url.path.endsWith('/finalize')) {
          finalized++;
          return http.Response('{}', 200);
        }
        throw StateError('Unexpected request: ${request.method} ${request.url}');
      });
      var queue = await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
      );
      await queue.drain();

      expect(uploaded, [next]);
      expect(completed, ['1']);
      expect(finalized, 1);
      expect(queue.pendingItemCount, 0);
      expect(queue.corruptedItemCount, 1);
      expect((readManifest()['corruptedItems'] as List).single['sequence'], 0);

      queue = await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
      );
      expect(queue.corruptedItemCount, 1);
      expect(queue.pendingItemCount, 0);
    });

    test('sets aside a finalize refused with a permanent 4xx and keeps retryable ones', () async {
      await writeManifest(const [], finalize: ['gone', 'busy', 'ok']);
      final attempts = <String, int>{};
      final client = MockClient((request) async {
        final session = request.url.pathSegments[request.url.pathSegments.length - 2];
        attempts[session] = (attempts[session] ?? 0) + 1;
        return switch (session) {
          'gone' => http.Response('not found', 404),
          'busy' => http.Response(jsonEncode({'error': 'slow down'}), attempts[session] == 1 ? 429 : 200),
          _ => http.Response('{}', 200),
        };
      });
      final queue = await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
      );
      await queue.drain();

      expect(queue.isFinalizeRejected('gone'), isTrue);
      expect(queue.isFinalizePending('gone'), isFalse);
      expect(queue.isFinalizePending('busy'), isTrue);
      expect(readManifest()['rejectedFinalizeSessions'], ['gone']);

      await queue.drain();

      expect(attempts['gone'], 1);
      expect(queue.isFinalizePending('busy'), isFalse);
      expect(queue.isFinalizePending('ok'), isFalse);
      expect(attempts['ok'], 1);
    });

    test('start is not held up by a hanging startup drain', () async {
      final bytes = Uint8List.fromList([3, 3, 3]);
      await File('${directory.path}/old_00000000.wav').writeAsBytes(bytes);
      await writeManifest([itemFor('old', 0, bytes)]);
      final presignStarted = Completer<void>();
      final release = Completer<void>();
      var sessionsCreated = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/upload-sessions')) {
          sessionsCreated++;
          return http.Response(jsonEncode({'sessionId': 'new'}), 200);
        }
        if (request.url.path.endsWith('/presign')) {
          if (!presignStarted.isCompleted) presignStarted.complete();
          await release.future;
          return http.Response(jsonEncode({'alreadyUploaded': true}), 200);
        }
        if (request.url.path.endsWith('/complete')) return http.Response('{}', 200);
        if (request.url.path.endsWith('/finalize')) return http.Response('{}', 200);
        throw StateError('Unexpected request: ${request.method} ${request.url}');
      });
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final service = BrainbaseR2IngestService.forTesting(
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
        directory: directory,
      );

      await service.resumePendingUploads();
      // The startup drain is now parked inside the network call.
      await presignStarted.future.timeout(const Duration(seconds: 2));

      final stopwatch = Stopwatch()..start();
      await service.start(codec: BleAudioCodec.pcm16, deviceId: 'device').timeout(const Duration(seconds: 2));
      stopwatch.stop();

      expect(sessionsCreated, 1);
      expect(stopwatch.elapsedMilliseconds, lessThanOrEqualTo(250));
      expect(readManifest()['activeSessionId'], 'new');
      expect(readManifest()['items'], hasLength(1));

      // Once the network answers, the startup drain finishes the old chunk.
      release.complete();
      for (var i = 0; i < 100 && (readManifest()['items'] as List).isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(readManifest()['items'], isEmpty);
      expect(File('${directory.path}/old_00000000.wav').existsSync(), isFalse);
    });

    test('a drain requested mid-drain runs once the current drain ends', () async {
      await writeManifest(const [], finalize: ['old']);
      final finalizeStarted = Completer<void>();
      final release = Completer<void>();
      final uploaded = <List<int>>[];
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/finalize')) {
          if (!finalizeStarted.isCompleted) finalizeStarted.complete();
          await release.future;
          return http.Response('{}', 200);
        }
        if (request.url.path.endsWith('/presign')) {
          return http.Response(jsonEncode({'putUrl': 'https://upload.test/c', 'alreadyUploaded': false}), 200);
        }
        if (request.method == 'PUT') {
          uploaded.add(request.bodyBytes);
          return http.Response('', 200);
        }
        if (request.url.path.endsWith('/complete')) return http.Response('{}', 200);
        throw StateError('Unexpected request: ${request.method} ${request.url}');
      });
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final queue = await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
      );
      final running = queue.drain();
      await finalizeStarted.future.timeout(const Duration(seconds: 2));

      await queue.enqueue(sessionId: 'new', sequence: 0, bytes: Uint8List.fromList([5, 5]));
      await queue.drain(); // Returns at once: a drain is already running.
      expect(queue.pendingItemCount, 1);

      release.complete();
      await running;

      expect(uploaded, [
        [5, 5],
      ]);
      expect(queue.pendingItemCount, 0);
      expect(queue.isFinalizePending('old'), isFalse);
    });

    test('sets aside a missing chunk when presign refuses it permanently', () async {
      await writeManifest([
        itemFor('expired', 0, Uint8List.fromList([1]))
      ]);
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/presign')) return http.Response('gone', 404);
        if (request.url.path.endsWith('/finalize')) return http.Response('{}', 200);
        throw StateError('Unexpected request: ${request.method} ${request.url}');
      });
      final queue = await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: client,
      );
      await queue.drain();

      expect(queue.pendingItemCount, 0);
      expect(queue.corruptedItemCount, 1);
    });

    for (final status in [503, 429]) {
      test('keeps a missing chunk queued when presign fails with $status', () async {
        await writeManifest([
          itemFor('later', 0, Uint8List.fromList([1]))
        ]);
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/presign')) return http.Response('{}', status);
          throw StateError('Unexpected request: ${request.method} ${request.url}');
        });
        final queue = await BrainbaseR2UploadQueue.openAt(
          directory: directory,
          baseUrl: 'https://ingest.test',
          token: 'test-token',
          client: client,
        );
        await queue.drain();

        expect(queue.pendingItemCount, 1);
        expect(queue.corruptedItemCount, 0);
      });
    }

    test('manifest save stays within 25 ms at p95', () async {
      final queue = await BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: 'https://ingest.test',
        token: 'test-token',
        client: MockClient((request) async => throw StateError('no network expected')),
      );
      // 30 s chunks: 120 items is an hour of queued audio.
      for (var i = 0; i < 120; i++) {
        await queue.enqueue(sessionId: 'long', sequence: i, bytes: Uint8List.fromList([i % 256]));
      }
      final samples = <int>[];
      for (var i = 0; i < 40; i++) {
        final stopwatch = Stopwatch()..start();
        await queue.markSessionActive('s$i');
        samples.add(stopwatch.elapsedMicroseconds);
      }
      samples.sort();
      final p95 = samples[(samples.length * 0.95).ceil() - 1];
      expect(p95, lessThanOrEqualTo(25000));
    });
  });
}
