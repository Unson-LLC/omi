import 'dart:convert';

import 'package:http/http.dart' as http;

class BrainbaseTranscriptException implements Exception {
  const BrainbaseTranscriptException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'BrainbaseTranscriptException($statusCode): $message';
}

class BrainbaseTranscriptSession {
  const BrainbaseTranscriptSession({
    required this.id,
    required this.deviceId,
    required this.status,
    required this.createdAt,
    this.recordedAt,
    this.transcriptionCompletedAt,
    required this.chunkCount,
    required this.nonEmptyChunkCount,
    required this.transcriptCharCount,
  });

  factory BrainbaseTranscriptSession.fromJson(Map<String, dynamic> json) {
    return BrainbaseTranscriptSession(
      id: json['id'] as String,
      deviceId: json['device_id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      createdAt: DateTime.parse(json['created_at'] as String),
      recordedAt: _dateTime(json['recorded_at']),
      transcriptionCompletedAt: _dateTime(json['transcription_completed_at']),
      chunkCount: _integer(json['chunk_count']),
      nonEmptyChunkCount: _integer(json['non_empty_chunk_count']),
      transcriptCharCount: _integer(json['transcript_char_count']),
    );
  }

  final String id;
  final String deviceId;
  final String status;
  final DateTime createdAt;
  final DateTime? recordedAt;
  final DateTime? transcriptionCompletedAt;
  final int chunkCount;
  final int nonEmptyChunkCount;
  final int transcriptCharCount;
}

class BrainbaseTranscriptChunk {
  const BrainbaseTranscriptChunk({required this.sequence, required this.text});

  factory BrainbaseTranscriptChunk.fromJson(Map<String, dynamic> json) {
    return BrainbaseTranscriptChunk(
      sequence: _integer(json['sequence']),
      text: json['text'] as String? ?? '',
    );
  }

  final int sequence;
  final String text;
}

class BrainbaseTranscriptPage {
  const BrainbaseTranscriptPage({required this.sessions, this.nextCursor});

  final List<BrainbaseTranscriptSession> sessions;
  final String? nextCursor;
}

class BrainbaseTranscriptDetail {
  const BrainbaseTranscriptDetail({
    required this.session,
    required this.chunks,
  });

  final BrainbaseTranscriptSession session;
  final List<BrainbaseTranscriptChunk> chunks;

  String get transcript => chunks.map((chunk) => chunk.text.trim()).where((text) => text.isNotEmpty).join('\n');
}

class BrainbaseTranscriptClient {
  BrainbaseTranscriptClient({
    required String baseUrl,
    required String token,
    http.Client? client,
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _token = token,
        _client = client ?? http.Client();

  static const String environmentBaseUrl = String.fromEnvironment(
    'BRAINBASE_INGEST_URL',
  );
  static const String environmentToken = String.fromEnvironment(
    'BRAINBASE_INGEST_TOKEN',
  );

  static bool get environmentEnabled => environmentBaseUrl.isNotEmpty && environmentToken.isNotEmpty;

  factory BrainbaseTranscriptClient.fromEnvironment() {
    if (!environmentEnabled) {
      throw const BrainbaseTranscriptException(
        'Brainbaseの取得先または認証情報が設定されていません。',
      );
    }
    return BrainbaseTranscriptClient(
      baseUrl: environmentBaseUrl,
      token: environmentToken,
    );
  }

  final String _baseUrl;
  final String _token;
  final http.Client _client;

  Future<BrainbaseTranscriptPage> listSessions({
    int limit = 50,
    String? cursor,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    final uri = Uri.parse('$_baseUrl/v1/transcript-sessions').replace(queryParameters: query);
    final body = await _getJson(uri);
    final sessions = (body['sessions'] as List<dynamic>? ?? const [])
        .map(
          (entry) => BrainbaseTranscriptSession.fromJson(
            entry as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
    return BrainbaseTranscriptPage(
      sessions: sessions,
      nextCursor: body['next_cursor'] as String?,
    );
  }

  Future<BrainbaseTranscriptDetail> getSession(String sessionId) async {
    final encodedId = Uri.encodeComponent(sessionId);
    final body = await _getJson(
      Uri.parse('$_baseUrl/v1/transcript-sessions/$encodedId'),
    );
    final chunks = (body['chunks'] as List<dynamic>? ?? const [])
        .map(
          (entry) => BrainbaseTranscriptChunk.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    chunks.sort((left, right) => left.sequence.compareTo(right.sequence));
    return BrainbaseTranscriptDetail(
      session: BrainbaseTranscriptSession.fromJson(
        body['session'] as Map<String, dynamic>,
      ),
      chunks: List.unmodifiable(chunks),
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    late http.Response response;
    try {
      response =
          await _client.get(uri, headers: {'authorization': 'Bearer $_token'}).timeout(const Duration(seconds: 15));
    } on BrainbaseTranscriptException {
      rethrow;
    } catch (error) {
      throw BrainbaseTranscriptException('通信に失敗しました: $error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BrainbaseTranscriptException(
        '文字起こしAPIがエラーを返しました。',
        statusCode: response.statusCode,
      );
    }
    try {
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const FormatException();
      return value;
    } catch (_) {
      throw const BrainbaseTranscriptException('文字起こしAPIの応答形式が不正です。');
    }
  }
}

int _integer(dynamic value) => value is num ? value.toInt() : 0;

DateTime? _dateTime(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
