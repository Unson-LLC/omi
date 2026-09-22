import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
}
