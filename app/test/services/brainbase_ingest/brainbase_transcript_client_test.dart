import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omi/services/brainbase_ingest/brainbase_transcript_client.dart';

void main() {
  test('lists transcript sessions and preserves the server cursor', () async {
    final client = BrainbaseTranscriptClient(
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/transcript-sessions');
        expect(request.url.queryParameters['limit'], '25');
        expect(request.url.queryParameters['cursor'], 'next-page');
        expect(request.headers['authorization'], 'Bearer test-token');
        return _jsonResponse({
          'sessions': [
            {
              'id': 'session-1',
              'device_id': 'fixture-device',
              'status': 'transcribed',
              'created_at': '2026-09-21T10:00:00.000Z',
              'recorded_at': '2026-09-21T09:59:00.000Z',
              'transcription_completed_at': '2026-09-21T10:01:00.000Z',
              'chunk_count': 2,
              'non_empty_chunk_count': 1,
              'transcript_char_count': 9,
            },
          ],
          'next_cursor': 'page-3',
        });
      }),
    );

    final page = await client.listSessions(limit: 25, cursor: 'next-page');

    expect(page.sessions, hasLength(1));
    expect(page.sessions.single.id, 'session-1');
    expect(page.sessions.single.status, 'transcribed');
    expect(page.sessions.single.transcriptCharCount, 9);
    expect(page.nextCursor, 'page-3');
  });

  test('loads detail and joins non-empty chunks in sequence order', () async {
    final client = BrainbaseTranscriptClient(
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: MockClient((request) async {
        expect(request.url.path, '/v1/transcript-sessions/session-1');
        return _jsonResponse({
          'session': {
            'id': 'session-1',
            'device_id': 'fixture-device',
            'status': 'transcribed',
            'created_at': '2026-09-21T10:00:00.000Z',
            'recorded_at': '2026-09-21T09:59:00.000Z',
            'chunk_count': 3,
            'non_empty_chunk_count': 2,
            'transcript_char_count': 9,
          },
          'chunks': [
            {
              'sequence': 2,
              'text': 'アイテム',
              'duration_seconds': 3.5,
              'segments_json': jsonEncode([
                {'start': 0.5, 'end': 1.5, 'text': 'アイテム'},
              ]),
            },
            {'sequence': 0, 'text': 'アクション', 'duration_seconds': 2},
            {'sequence': 1, 'text': '  ', 'duration_seconds': 4},
          ],
        });
      }),
    );

    final detail = await client.getSession('session-1');

    expect(detail.transcript, 'アクション\nアイテム');
    expect(detail.chunks.map((chunk) => chunk.sequence), [0, 1, 2]);
    expect(detail.chunks[2].durationSeconds, 3.5);
    expect(detail.chunks[2].segments, hasLength(1));
    expect(detail.chunks[2].segments.single.start, 0.5);
    expect(detail.chunks[2].segments.single.end, 1.5);
  });

  test('falls back when any recognition segment is malformed', () async {
    final client = BrainbaseTranscriptClient(
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: MockClient((_) async {
        return _jsonResponse({
          'session': {
            'id': 'session-1',
            'device_id': 'fixture-device',
            'status': 'transcribed',
            'created_at': '2026-09-21T10:00:00.000Z',
            'chunk_count': 1,
            'non_empty_chunk_count': 1,
            'transcript_char_count': 4,
          },
          'chunks': [
            {
              'sequence': 0,
              'text': '本文',
              'duration_seconds': 4,
              'segments_json': jsonEncode([
                {'start': -1, 'end': 1, 'text': '負の開始'},
                {'start': 2, 'end': 1, 'text': '逆順'},
                {'start': 1, 'end': 2, 'text': '有効'},
                {'start': 2, 'end': 5, 'text': '長すぎる'},
                {'start': 1, 'end': 2, 'text': '  '},
              ]),
            },
          ],
        });
      }),
    );

    final detail = await client.getSession('session-1');

    expect(detail.chunks.single.text, '本文');
    expect(detail.chunks.single.segments, isEmpty);
  });

  test('does not turn an API failure into an empty list', () async {
    final client = BrainbaseTranscriptClient(
      baseUrl: 'https://ingest.test',
      token: 'test-token',
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );

    expect(
      () => client.listSessions(),
      throwsA(
        isA<BrainbaseTranscriptException>().having(
          (error) => error.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
  });
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
