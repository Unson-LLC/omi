import 'package:omi/backend/schema/conversation.dart';
import 'package:omi/backend/schema/structured.dart';
import 'package:omi/backend/schema/transcript_segment.dart';
import 'package:omi/providers/conversation_provider.dart';
import 'package:omi/services/brainbase_ingest/brainbase_transcript_client.dart';

typedef BrainbasePageLoader = Future<BrainbaseTranscriptPage> Function({int limit, String? cursor});
typedef BrainbaseDetailLoader = Future<BrainbaseTranscriptDetail> Function(String id);

class BrainbaseConversationSource {
  BrainbaseConversationSource({required this.pageLoader, required this.detailLoader});

  factory BrainbaseConversationSource.fromClient(BrainbaseTranscriptClient client) =>
      BrainbaseConversationSource(pageLoader: client.listSessions, detailLoader: client.getSession);

  final BrainbasePageLoader pageLoader;
  final BrainbaseDetailLoader detailLoader;
  String? _nextCursor;
  final List<ServerConversation> _cached = [];

  Future<({List<ServerConversation> items, bool ok})> fetchList() async {
    _nextCursor = null;
    _cached.clear();
    try {
      final page = await pageLoader(limit: 50, cursor: null);
      _nextCursor = page.nextCursor;
      final items = page.sessions.map(_conversationFromSession).toList(growable: false);
      _cached.addAll(items);
      return (items: items, ok: true);
    } catch (_) {
      return (items: <ServerConversation>[], ok: false);
    }
  }

  Future<({List<ServerConversation> items, bool ok, bool truncated})> fetchNextPage() async {
    final cursor = _nextCursor;
    if (cursor == null) return (items: <ServerConversation>[], ok: true, truncated: true);
    try {
      final page = await pageLoader(limit: 50, cursor: cursor);
      _nextCursor = page.nextCursor;
      final items = page.sessions.map(_conversationFromSession).toList(growable: false);
      _cached.addAll(items);
      return (items: items, ok: true, truncated: _nextCursor == null);
    } catch (_) {
      return (items: <ServerConversation>[], ok: false, truncated: false);
    }
  }

  Future<ServerConversation?> fetchDetails(String id) async {
    try {
      final detail = await detailLoader(id);
      final segments = <TranscriptSegment>[];
      final chunks = detail.chunks.toList()..sort((left, right) => left.sequence.compareTo(right.sequence));
      var elapsedSeconds = 0.0;
      for (final chunk in chunks) {
        final localSegments = chunk.segments;
        if (localSegments.isNotEmpty) {
          for (var index = 0; index < localSegments.length; index++) {
            final localSegment = localSegments[index];
            segments.add(
              _transcriptSegment(
                detail.session.id,
                chunk.sequence,
                index,
                localSegment.text,
                start: elapsedSeconds + localSegment.start,
                end: elapsedSeconds + localSegment.end,
              ),
            );
          }
        } else if (chunk.text.trim().isNotEmpty) {
          // A chunk can retain recognized text even when the provider omitted
          // segment metadata. Use the known audio span when available; an
          // unavailable span remains zero rather than becoming a fake second.
          final durationSeconds = _validDuration(chunk.durationSeconds);
          segments.add(
            _transcriptSegment(
              detail.session.id,
              chunk.sequence,
              0,
              chunk.text,
              start: elapsedSeconds,
              end: elapsedSeconds + (durationSeconds ?? 0),
            ),
          );
        }

        final durationSeconds = _validDuration(chunk.durationSeconds);
        if (durationSeconds != null) elapsedSeconds += durationSeconds;
      }
      for (var index = 0; index < segments.length; index++) {
        segments[index].idx = index;
      }
      return _conversationFromSession(detail.session, transcriptSegments: segments);
    } catch (_) {
      return null;
    }
  }

  TranscriptSegment _transcriptSegment(
    String sessionId,
    int sequence,
    int segmentIndex,
    String text, {
    required double start,
    required double end,
  }) {
    return TranscriptSegment(
      id: '$sessionId:$sequence${segmentIndex == 0 ? '' : ':$segmentIndex'}',
      text: text,
      speaker: 'SPEAKER_00',
      isUser: false,
      personId: null,
      start: start,
      end: end,
      translations: const [],
      sttProvider: 'brainbase-cloudflare',
    );
  }

  Future<({ServerConversation? item, bool ok})> fetchLifecycle(String id) async {
    final item = await fetchDetails(id);
    return (item: item, ok: item != null);
  }

  Future<(List<ServerConversation>, int, int)> search(
    String query, {
    int? page,
    int? limit,
    required bool includeDiscarded,
    DateTime? startDate,
    DateTime? endDate,
    String? speakerId,
  }) async {
    final normalized = query.trim().toLowerCase();
    final matches = _cached.where((conversation) {
      final timestamp = conversation.startedAt ?? conversation.createdAt;
      if (startDate != null && timestamp.isBefore(startDate)) return false;
      if (endDate != null && timestamp.isAfter(endDate)) return false;
      if (normalized.isEmpty) return true;
      return conversation.structured.title.toLowerCase().contains(normalized) ||
          conversation.structured.overview.toLowerCase().contains(normalized);
    }).toList(growable: false);
    return (matches, 1, 1);
  }

  ServerConversation _conversationFromSession(
    BrainbaseTranscriptSession session, {
    List<TranscriptSegment> transcriptSegments = const [],
  }) {
    final createdAt = session.recordedAt ?? session.createdAt;
    return ServerConversation(
      id: session.id,
      createdAt: createdAt,
      startedAt: createdAt,
      finishedAt: session.transcriptionCompletedAt,
      structured: Structured(
        'Omi 録音',
        'Cloudflare / Brainbase · ${session.status}',
        emoji: '🎙️',
      ),
      transcriptSegments: transcriptSegments,
      source: ConversationSource.omi,
      externalIntegration: ConversationExternalData(text: 'Cloudflare / Brainbase'),
      status: _status(session.status),
    );
  }

  ConversationStatus _status(String value) => switch (value.toLowerCase()) {
        'completed' || 'transcribed' || 'ready' => ConversationStatus.completed,
        'failed' => ConversationStatus.failed,
        'recording' || 'capturing' || 'in_progress' => ConversationStatus.in_progress,
        _ => ConversationStatus.processing,
      };
}

double? _validDuration(double? value) {
  if (value == null || !value.isFinite || value < 0) return null;
  return value;
}

ConversationProvider createBrainbaseConversationProvider({BrainbaseTranscriptClient? client}) {
  final source = BrainbaseConversationSource.fromClient(client ?? BrainbaseTranscriptClient.fromEnvironment());
  return ConversationProvider(
    conversationListFetcher: source.fetchList,
    conversationPageFetcher: source.fetchNextPage,
    conversationLifecycleFetcher: source.fetchLifecycle,
    conversationDetailsFetcher: source.fetchDetails,
    conversationSearchFetcher: source.search,
    dailySummariesChecker: () async => false,
    conversationDeleteFetcher: (_) async => false,
    isSignedIn: () => true,
  );
}
