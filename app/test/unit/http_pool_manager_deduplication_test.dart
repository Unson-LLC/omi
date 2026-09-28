import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omi/backend/http/http_pool_manager.dart';

void main() {
  final uri = Uri.parse('https://example.invalid/resource');

  test('handled concurrent GET failure has no uncaught copy and allows recovery', () async {
    final uncaught = <Object>[];
    final handled = <Object>[];
    final finished = Completer<void>();
    const failure = SocketException('offline');
    var calls = 0;
    runZonedGuarded(() async {
      final gate = Completer<http.Response>();
      final manager = HttpPoolManager.withClient(MockClient((_) {
        calls++;
        return calls == 1 ? gate.future : Future.value(http.Response('recovered', 200));
      }));
      try {
        Future<void> request() async {
          try {
            await manager.send(() => http.Request('GET', uri), retries: 0);
          } catch (error) {
            handled.add(error);
          }
        }

        final first = request();
        final second = request();
        await Future<void>.delayed(Duration.zero);
        gate.completeError(failure);
        await Future.wait([first, second]);
        final recovered = await manager.send(() => http.Request('GET', uri), retries: 0);
        expect(recovered.body, 'recovered');
        await Future<void>.delayed(Duration.zero);
      } finally {
        manager.dispose();
        finished.complete();
      }
    }, (error, stack) => uncaught.add(error));
    await finished.future;
    expect(handled, [same(failure), same(failure)]);
    expect(calls, 2);
    expect(uncaught, isEmpty);
  });

  test('concurrent successful GETs share transport and clear after completion', () async {
    var calls = 0;
    final gate = Completer<http.Response>();
    final manager = HttpPoolManager.withClient(MockClient((_) {
      calls++;
      return calls == 1 ? gate.future : Future.value(http.Response('next', 200));
    }));
    addTearDown(manager.dispose);
    final first = manager.send(() => http.Request('GET', uri));
    final second = manager.send(() => http.Request('GET', uri));
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    gate.complete(http.Response('shared', 200));
    final responses = await Future.wait([first, second]);
    expect(responses.map((response) => response.body), ['shared', 'shared']);
    expect((await manager.send(() => http.Request('GET', uri))).body, 'next');
    expect(calls, 2);
  });

  test('POST requests with the same URL remain independent', () async {
    var calls = 0;
    final manager = HttpPoolManager.withClient(MockClient((_) async {
      calls++;
      return http.Response('ok', 200);
    }));
    addTearDown(manager.dispose);
    await Future.wait([
      manager.send(() => http.Request('POST', uri)),
      manager.send(() => http.Request('POST', uri)),
    ]);
    expect(calls, 2);
  });
}
