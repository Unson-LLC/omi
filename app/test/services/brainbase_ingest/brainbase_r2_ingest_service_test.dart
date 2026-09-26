import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omi/services/brainbase_ingest/brainbase_r2_ingest_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
