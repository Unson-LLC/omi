import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omi/pages/conversation_detail/conversation_detail_provider.dart';
import 'package:omi/pages/conversation_detail/page.dart';
import 'package:omi/providers/app_provider.dart';
import 'package:omi/providers/conversation_provider.dart';
import 'package:omi/services/brainbase_ingest/brainbase_conversation_source.dart';
import 'package:omi/services/brainbase_ingest/brainbase_transcript_client.dart';

import '../../test/support/typed_conversation_screen.dart';
import 'support/hermetic_boot.dart';
import 'support/journey_evidence.dart';

/// Cloudflare transcript readback journey.
///
/// A saved transcript session is served through the same HTTP contract as the
/// personal Cloudflare backend. The production adapter must turn it into the
/// existing conversation UI model, render it in the list, fetch its chunks,
/// and render the transcript in the existing detail screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saved Cloudflare transcript renders in the existing list and detail UI', (tester) async {
    final evidence = JourneyEvidence.begin(journeyId: 'j7_cloudflare_transcript_ui', lane: journeyLane);
    final server = await JourneyHermeticBoot.start();
    addTearDown(JourneyHermeticBoot.stop);

    const sessionId = 'cloudflare-session-j7-0001';
    server.transcriptSessions.add({
      'id': sessionId,
      'device_id': 'omi-fixture-device',
      'status': 'completed',
      'created_at': '2026-09-22T03:00:00.000Z',
      'recorded_at': '2026-09-22T03:00:00.000Z',
      'transcription_completed_at': '2026-09-22T03:00:08.000Z',
      'chunk_count': 2,
      'non_empty_chunk_count': 2,
      'transcript_char_count': 30,
    });
    server.transcriptChunksBySession[sessionId] = [
      {'sequence': 2, 'text': '文字起こし表示を確認します'},
      {'sequence': 1, 'text': '自動E2Eで'},
    ];

    final client = BrainbaseTranscriptClient(
      baseUrl: server.baseUrl,
      token: JourneyHermeticBoot.fixtureToken,
    );
    final conversationProvider = createBrainbaseConversationProvider(client: client);
    await conversationProvider.forceRefreshConversations();

    expect(server.countOf('GET', '/v1/transcript-sessions'), 1);
    expect(conversationProvider.conversations, hasLength(1));
    final conversation = conversationProvider.conversations.single;
    expect(conversation.id, sessionId);
    expect(conversation.structured.title, 'Omi 録音');
    expect(conversation.structured.overview, contains('Cloudflare / Brainbase'));
    evidence.record(
      'cloudflare-session-mapped',
      ok: server.countOf('GET', '/v1/transcript-sessions') == 1 &&
          conversation.id == sessionId &&
          conversation.structured.title == 'Omi 録音',
      invariant: 'saved Cloudflare transcript session maps into the existing conversation model',
    );

    await tester.pumpWidget(await buildTypedConversationScreen(conversationProvider));
    await tester.pumpAndSettle();
    evidence.record(
      'conversation-list-rendered',
      ok: find.text('Omi 録音').evaluate().length == 1,
      invariant: 'mapped Cloudflare transcript appears in the existing conversation list UI',
    );
    expect(find.text('Omi 録音'), findsOneWidget);

    final appProvider = AppProvider();
    final detailProvider = ConversationDetailProvider()
      ..setProviders(appProvider, conversationProvider)
      ..selectedDate = conversationLocalDayKey(conversation.createdAt);
    await JourneyHermeticBoot.pumpPage(
      tester,
      page: ConversationDetailPage(conversation: conversation, initialTabIndex: 0),
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
        ChangeNotifierProvider<ConversationDetailProvider>.value(value: detailProvider),
        ChangeNotifierProvider<ConversationProvider>.value(value: conversationProvider),
      ],
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final detailRequested = server.countOf('GET', '/v1/transcript-sessions/$sessionId') >= 1;
    final firstChunkRendered = find.textContaining('自動E2Eで', findRichText: true).evaluate().isNotEmpty;
    final secondChunkRendered = find.textContaining('文字起こし表示を確認します', findRichText: true).evaluate().isNotEmpty;
    evidence.record(
      'transcript-detail-rendered',
      ok: detailRequested && firstChunkRendered && secondChunkRendered,
      invariant: 'the existing detail UI fetches and displays saved Cloudflare transcript chunks',
    );
    expect(detailRequested, isTrue);
    expect(
      find.textContaining('自動E2Eで', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('文字起こし表示を確認します', findRichText: true),
      findsWidgets,
    );
    await evidence.write();
  });
}
