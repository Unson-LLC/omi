import 'package:flutter_test/flutter_test.dart';
import 'package:omi/backend/schema/conversation.dart';
import 'package:omi/services/brainbase_ingest/brainbase_conversation_source.dart';
import 'package:omi/services/brainbase_ingest/brainbase_transcript_client.dart';

void main() {
  final firstSession = BrainbaseTranscriptSession(
    id: 'session-1',
    deviceId: 'omi-1',
    status: 'completed',
    createdAt: DateTime.parse('2026-09-21T01:00:00Z'),
    recordedAt: DateTime.parse('2026-09-21T00:59:00Z'),
    transcriptionCompletedAt: DateTime.parse('2026-09-21T01:01:00Z'),
    chunkCount: 2,
    nonEmptyChunkCount: 2,
    transcriptCharCount: 12,
  );

  test('Cloudflare sessions map into the existing Omi conversation model', () async {
    final source = BrainbaseConversationSource(
      pageLoader: ({limit = 50, cursor}) async => BrainbaseTranscriptPage(
        sessions: [firstSession],
        nextCursor: 'next-page',
      ),
      detailLoader: (_) async => BrainbaseTranscriptDetail(
        session: firstSession,
        chunks: const [
          BrainbaseTranscriptChunk(sequence: 2, text: '二番目'),
          BrainbaseTranscriptChunk(sequence: 1, text: '一番目'),
        ],
      ),
    );

    final page = await source.fetchList();
    expect(page.ok, isTrue);
    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'session-1');
    expect(page.items.single.source, ConversationSource.omi);
    expect(page.items.single.structured.title, 'Omi 録音');
    expect(page.items.single.status, ConversationStatus.completed);

    final detail = await source.fetchDetails('session-1');
    expect(detail, isNotNull);
    expect(detail!.transcriptSegments.map((segment) => segment.text).toList(), ['一番目', '二番目']);
    expect(detail.transcriptSegments.map((segment) => segment.idx).toList(), [0, 1]);
  });

  test('pagination keeps the cursor and reports the terminal page', () async {
    final cursors = <String?>[];
    final source = BrainbaseConversationSource(
      pageLoader: ({limit = 50, cursor}) async {
        cursors.add(cursor);
        return BrainbaseTranscriptPage(
          sessions: [firstSession],
          nextCursor: cursor == null ? 'page-2' : null,
        );
      },
      detailLoader: (_) async => BrainbaseTranscriptDetail(session: firstSession, chunks: const []),
    );

    expect((await source.fetchList()).ok, isTrue);
    final secondPage = await source.fetchNextPage();

    expect(cursors, [null, 'page-2']);
    expect(secondPage.ok, isTrue);
    expect(secondPage.truncated, isTrue);
  });

  test('transport failures remain failures instead of becoming an empty success', () async {
    final source = BrainbaseConversationSource(
      pageLoader: ({limit = 50, cursor}) => throw const BrainbaseTranscriptException('offline'),
      detailLoader: (_) => throw const BrainbaseTranscriptException('offline'),
    );

    final result = await source.fetchList();
    expect(result.ok, isFalse);
    expect(result.items, isEmpty);
    expect(await source.fetchDetails('session-1'), isNull);
  });
}
