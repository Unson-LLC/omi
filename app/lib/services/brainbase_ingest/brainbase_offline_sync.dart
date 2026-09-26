import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:omi/backend/schema/bt_device/bt_device.dart';
import 'package:omi/env/env.dart';
import 'package:omi/env/environment_profile.dart';
import 'package:omi/utils/audio/audio_transcoder.dart';
import 'package:omi/utils/batch_recording.dart';

/// Progress reported while a local WAL batch is being sent to the ingest
/// worker. Bytes refer to the source WAL files, so the value remains stable
/// when a file is transcoded before its PUT request.
typedef BrainbaseOfflineUploadProgress = void Function(
  int bytesSent,
  int totalBytes,
  double speedKBps,
);

class BrainbaseOfflineSyncException implements Exception {
  BrainbaseOfflineSyncException(
    this.message, {
    this.statusCode,
    this.retryAfterSeconds,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final int? retryAfterSeconds;
  final Object? cause;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' ($statusCode)';
    return 'BrainbaseOfflineSyncException$code: $message';
  }
}

/// A server-side view of one upload session.
class BrainbaseOfflineStatus {
  const BrainbaseOfflineStatus({
    required this.sessionId,
    required this.status,
    required this.chunkCount,
    required this.httpStatus,
    this.recordedAt,
    this.transcript = '',
    this.conversationId,
  });

  final String sessionId;
  final String status;
  final int chunkCount;
  final DateTime? recordedAt;
  final String transcript;
  final String? conversationId;
  final int httpStatus;

  bool get isTranscribed => status.toLowerCase() == 'transcribed';

  @override
  String toString() => 'BrainbaseOfflineStatus(sessionId: $sessionId, status: $status, chunkCount: $chunkCount)';
}

/// Durable client for the Cloudflare transcript-session upload contract.
///
/// The client deliberately owns only transport and local WAL state. Mapping
/// the result to the app's generic sync model belongs to the caller, which
/// keeps this service independent from conversation routing.
class BrainbaseOfflineSync {
  BrainbaseOfflineSync({
    required String baseUrl,
    required this.token,
    http.Client? client,
    Directory? journalDirectory,
    this.requestTimeout = const Duration(seconds: 15),
    this.uploadTimeout = const Duration(seconds: 60),
    this.authFailureCooldown = const Duration(seconds: 30),
  })  : _client = client ?? http.Client(),
        _configuredJournalDirectory = journalDirectory,
        _baseUri = _parseBaseUrl(baseUrl);

  static const _journalVersion = 1;
  static const _minimumChunkDurationSeconds = 5;
  static const _journalName = 'journal.json';

  final String token;
  final http.Client _client;
  final Directory? _configuredJournalDirectory;
  final Uri _baseUri;
  final Duration requestTimeout;
  final Duration uploadTimeout;
  final Duration authFailureCooldown;

  File? _journalFile;
  Future<void>? _journalInitialization;
  Map<String, _JournalBatch> _journal = <String, _JournalBatch>{};
  Future<void> _serial = Future<void>.value();
  DateTime? _authFailureUntil;
  int? _authFailureStatus;

  /// Returns a client only for local_dev builds.
  ///
  /// The production-family profiles intentionally return null even when the
  /// two defines are present. This keeps an accidental define from routing
  /// production recordings to a diagnostic ingest endpoint.
  static BrainbaseOfflineSync? fromEnvironment({
    http.Client? client,
    Directory? journalDirectory,
  }) {
    try {
      if (Env.profile != AppEnvironmentProfile.localDev) return null;
    } catch (_) {
      return null;
    }

    const baseUrl = String.fromEnvironment('BRAINBASE_INGEST_URL');
    const token = String.fromEnvironment('BRAINBASE_INGEST_TOKEN');
    if (baseUrl.trim().isEmpty || token.trim().isEmpty) return null;
    return BrainbaseOfflineSync(
      baseUrl: baseUrl,
      token: token,
      client: client,
      journalDirectory: journalDirectory,
    );
  }

  /// Uploads the given local WAL files as one transcript session.
  ///
  /// A content hash in the journal identifies the batch. If a previous run
  /// created a session, this method resumes that session instead of creating
  /// a second one.
  Future<String> upload(
    List<File> files, {
    BrainbaseOfflineUploadProgress? onProgress,
    String? conversationId,
  }) {
    final operation = _serial.then<String>(
      (_) => _uploadImpl(
        files,
        onProgress: onProgress,
        conversationId: conversationId,
      ),
    );
    _serial = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  /// Fetches one Worker transcript session. The `cloudflare:` prefix used by
  /// the legacy local job records is accepted for callers that reconcile old
  /// pending entries.
  Future<BrainbaseOfflineStatus> fetchStatus(String sessionId) async {
    final normalized = _normalizeSessionId(sessionId);
    final response = await _request(
      operation: 'fetch transcript session',
      timeout: requestTimeout,
      send: () => _client.get(
        _uri('/v1/transcript-sessions/${Uri.encodeComponent(normalized)}'),
        headers: _authHeaders,
      ),
    );
    final body = _decodeObject(response, 'fetch transcript session');
    final status = _parseStatus(body, httpStatus: response.statusCode);
    if (status.sessionId != normalized) {
      throw BrainbaseOfflineSyncException(
        'transcript session response id does not match the requested session',
        cause: <String, String>{'requested': normalized, 'received': status.sessionId},
      );
    }
    return status;
  }

  Future<String> _uploadImpl(
    List<File> files, {
    required BrainbaseOfflineUploadProgress? onProgress,
    required String? conversationId,
  }) async {
    if (files.isEmpty) {
      throw BrainbaseOfflineSyncException('offline upload requires at least one file');
    }
    final metadata = <_RecordingMetadata>[];
    var totalBytes = 0;
    for (final file in files) {
      final item = await _parseMetadata(file);
      metadata.add(item);
      totalBytes += item.byteLength;
    }

    await _ensureJournal();
    final hash = await _hashBatch(files, conversationId);
    var batch = _journal[hash];
    var sessionId = batch?.sessionId;
    BrainbaseOfflineStatus? existingStatus;
    if (sessionId != null) {
      // Always check the server before presign. A closed session must be
      // finalized/reconciled, never sent another presign request.
      existingStatus = await fetchStatus(sessionId);
      if (existingStatus.isTranscribed) return sessionId;
      _validateResumableStatus(existingStatus);
      if (existingStatus.status.toLowerCase() != 'open') {
        await _finalize(sessionId);
        return sessionId;
      }
    } else {
      final firstFrames = _parseFrames(await metadata.first.file.readAsBytes());
      final durationSeconds = math
          .max(
            _minimumChunkDurationSeconds,
            (firstFrames.length * metadata.first.frameSize / metadata.first.sampleRate).round(),
          )
          .toInt();
      sessionId = await _createSession(metadata.first, conversationId, durationSeconds);
      batch = _JournalBatch(sessionId: sessionId, completedSequences: <int>{});
      _journal[hash] = batch;
      await _saveJournal();
    }

    final completed = <int>{...?batch?.completedSequences};
    final stopwatch = Stopwatch()..start();
    var sentBytes = 0;
    for (var sequence = 0; sequence < files.length; sequence++) {
      final item = metadata[sequence];
      if (completed.contains(sequence)) {
        sentBytes += item.byteLength;
        _reportProgress(onProgress, sentBytes, totalBytes, stopwatch);
        continue;
      }
      final raw = await item.file.readAsBytes();
      final wav = _transcode(item, raw);
      final digest = sha256.convert(wav).toString();
      final presign = await _presign(
        sessionId: sessionId,
        sequence: sequence,
        digest: digest,
        byteLength: wav.length,
      );
      if (presign['alreadyUploaded'] != true) {
        final putUrl = presign['putUrl'];
        if (putUrl is! String || putUrl.isEmpty) {
          throw BrainbaseOfflineSyncException(
            'presign response did not include putUrl',
            cause: presign,
          );
        }
        await _putWav(Uri.parse(putUrl), wav, digest);
      }
      await _complete(sessionId, sequence);
      completed.add(sequence);
      batch!.completedSequences = completed;
      await _saveJournal();
      sentBytes += item.byteLength;
      _reportProgress(onProgress, sentBytes, totalBytes, stopwatch);
    }
    stopwatch.stop();

    // Finalize is safe to repeat. Keeping the journal until this succeeds
    // makes a lost finalize response retryable without creating a new session.
    await _finalize(sessionId);
    return sessionId;
  }

  Future<_RecordingMetadata> _parseMetadata(File file) async {
    final name = p.basename(file.path);
    final parsed = BatchRecordingInfo.fromFileName(name);
    if (parsed == null) {
      throw BrainbaseOfflineSyncException('unsupported WAL filename: $name');
    }
    final match = RegExp(
      r'^audio_(.+)_(pcm16|pcm8|opus(?:_fs320)?)_(\d+)_(\d+)_fs(\d+)(?:_r[^_]+)?_(\d+)\.bin$',
    ).firstMatch(name);
    if (match == null) {
      throw BrainbaseOfflineSyncException('WAL filename metadata is incomplete: $name');
    }
    final sampleRate = int.tryParse(match.group(3)!);
    final channels = int.tryParse(match.group(4)!);
    final frameSize = int.tryParse(match.group(5)!);
    final timestamp = int.tryParse(match.group(6)!);
    if (sampleRate == null ||
        sampleRate <= 0 ||
        channels == null ||
        channels <= 0 ||
        frameSize == null ||
        frameSize <= 0 ||
        timestamp == null) {
      throw BrainbaseOfflineSyncException('invalid WAL filename metadata: $name');
    }
    if (channels != 1) {
      throw BrainbaseOfflineSyncException(
        'Worker accepts mono audio only (channels=$channels): $name',
      );
    }
    final codecName = match.group(2)!;
    final codec = mapNameToCodec(codecName);
    if (!codec.isCustomSttSupported) {
      throw BrainbaseOfflineSyncException('unsupported audio codec: $codecName');
    }
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw BrainbaseOfflineSyncException('WAL path is not a file: ${file.path}');
    }
    return _RecordingMetadata(
      file: file,
      deviceId: match.group(1)!,
      codec: codec,
      sampleRate: sampleRate,
      channels: channels,
      frameSize: frameSize,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        timestamp > 100000000000 ? timestamp : timestamp * 1000,
        isUtc: true,
      ),
      byteLength: stat.size,
    );
  }

  Uint8List _transcode(_RecordingMetadata metadata, Uint8List raw) {
    final frames = _parseFrames(raw);
    final transcoder = AudioTranscoderFactory.createToWav(
      sourceCodec: metadata.codec,
      sampleRate: metadata.sampleRate,
      channels: metadata.channels,
    );
    if (metadata.codec == BleAudioCodec.opus || metadata.codec == BleAudioCodec.opusFS320) {
      // OpusToWavTranscoder.transcodeFrames intentionally skips bad frames.
      // Validate each frame first so a damaged WAL cannot be acknowledged as a
      // complete upload containing only a partial recording.
      final validator = AudioTranscoderFactory.createToWav(
        sourceCodec: metadata.codec,
        sampleRate: metadata.sampleRate,
        channels: metadata.channels,
      );
      for (var index = 0; index < frames.length; index++) {
        try {
          validator.transcode(frames[index]);
        } catch (error) {
          throw BrainbaseOfflineSyncException(
            'unable to decode Opus frame $index in ${p.basename(metadata.file.path)}',
            cause: error,
          );
        }
      }
    }
    final wav = transcoder.transcodeFrames(frames);
    if (wav.length <= 44) {
      throw BrainbaseOfflineSyncException(
        'audio WAL produced no decodable audio: ${p.basename(metadata.file.path)}',
      );
    }
    return wav;
  }

  List<Uint8List> _parseFrames(Uint8List data) {
    final frames = <Uint8List>[];
    var offset = 0;
    while (offset < data.length) {
      if (data.length - offset < 4) {
        throw BrainbaseOfflineSyncException('truncated WAL frame header');
      }
      final length = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.little);
      offset += 4;
      if (length == 0 || length > data.length - offset) {
        throw BrainbaseOfflineSyncException('invalid WAL frame length: $length');
      }
      frames.add(Uint8List.sublistView(data, offset, offset + length));
      offset += length;
    }
    if (frames.isEmpty) throw BrainbaseOfflineSyncException('empty audio WAL');
    return frames;
  }

  Future<String> _hashBatch(List<File> files, String? conversationId) async {
    final output = _DigestSink();
    final input = sha256.startChunkedConversion(output);
    void addText(String value) => input.add(utf8.encode(value));
    addText('conversation:${conversationId ?? ''}\n');
    for (final file in files) {
      final name = p.basename(file.path);
      final length = await file.length();
      addText('file:$name:$length\n');
      final handle = await file.open();
      try {
        final buffer = Uint8List(64 * 1024);
        while (true) {
          final count = await handle.readInto(buffer);
          if (count == 0) break;
          input.add(buffer.sublist(0, count));
        }
      } finally {
        await handle.close();
      }
    }
    input.close();
    return output.value.toString();
  }

  Future<String> _createSession(
    _RecordingMetadata first,
    String? conversationId,
    int chunkDurationSeconds,
  ) async {
    final payload = <String, dynamic>{
      'deviceId': first.deviceId,
      'sourceCodec': first.codec.toString(),
      'sampleRate': first.sampleRate,
      'channels': first.channels,
      'chunkDurationSeconds': chunkDurationSeconds,
      'recordedAt': first.recordedAt.toIso8601String(),
    };
    if (conversationId != null && conversationId.trim().isNotEmpty) {
      payload['sourceConversationId'] = conversationId.trim();
    }
    final response = await _request(
      operation: 'create upload session',
      timeout: requestTimeout,
      send: () => _client.post(
        _uri('/v1/upload-sessions'),
        headers: _authHeaders,
        body: jsonEncode(payload),
      ),
    );
    final body = _decodeObject(response, 'create upload session');
    final sessionId = body['sessionId'] ?? body['session_id'];
    if (sessionId is! String || sessionId.isEmpty) {
      throw BrainbaseOfflineSyncException('create upload session response omitted sessionId', cause: body);
    }
    return sessionId;
  }

  Future<Map<String, dynamic>> _presign({
    required String sessionId,
    required int sequence,
    required String digest,
    required int byteLength,
  }) async {
    final response = await _request(
      operation: 'presign audio chunk',
      timeout: requestTimeout,
      send: () => _client.post(
        _uri('/v1/upload-sessions/${Uri.encodeComponent(sessionId)}/chunks/$sequence/presign'),
        headers: _authHeaders,
        body: jsonEncode({
          'sha256': digest,
          'byteLength': byteLength,
          'contentType': 'audio/wav',
        }),
      ),
    );
    return _decodeObject(response, 'presign audio chunk');
  }

  Future<void> _putWav(Uri putUrl, Uint8List wav, String digest) async {
    final response = await _request(
      operation: 'upload audio chunk',
      timeout: uploadTimeout,
      authenticated: false,
      send: () => _client.put(
        putUrl,
        headers: {
          'content-type': 'audio/wav',
          'x-amz-meta-sha256': digest,
        },
        body: wav,
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _responseException(response, 'upload audio chunk');
    }
  }

  Future<void> _complete(String sessionId, int sequence) async {
    final response = await _request(
      operation: 'complete audio chunk',
      timeout: requestTimeout,
      send: () => _client.post(
        _uri('/v1/upload-sessions/${Uri.encodeComponent(sessionId)}/chunks/$sequence/complete'),
        headers: _authHeaders,
      ),
    );
    _decodeObject(response, 'complete audio chunk');
  }

  Future<void> _finalize(String sessionId) async {
    final response = await _request(
      operation: 'finalize upload session',
      timeout: requestTimeout,
      send: () => _client.post(
        _uri('/v1/upload-sessions/${Uri.encodeComponent(sessionId)}/finalize'),
        headers: _authHeaders,
      ),
    );
    _decodeObject(response, 'finalize upload session');
  }

  Future<http.Response> _request({
    required String operation,
    required Duration timeout,
    required Future<http.Response> Function() send,
    bool authenticated = true,
  }) async {
    if (authenticated) _throwAuthCooldownIfActive(operation);
    try {
      final response = await send().timeout(timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        _authFailureUntil = DateTime.now().add(authFailureCooldown);
        _authFailureStatus = response.statusCode;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _responseException(response, operation);
      }
      return response;
    } on BrainbaseOfflineSyncException {
      rethrow;
    } on TimeoutException catch (error) {
      throw BrainbaseOfflineSyncException('$operation timed out', cause: error);
    } on IOException catch (error) {
      throw BrainbaseOfflineSyncException('$operation failed', cause: error);
    } catch (error) {
      throw BrainbaseOfflineSyncException('$operation failed', cause: error);
    }
  }

  BrainbaseOfflineSyncException _responseException(http.Response response, String operation) {
    return BrainbaseOfflineSyncException(
      '$operation failed with HTTP ${response.statusCode}',
      statusCode: response.statusCode,
      retryAfterSeconds: _retryAfter(response),
      cause: response.body,
    );
  }

  Map<String, dynamic> _decodeObject(http.Response response, String operation) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    try {
      final value = jsonDecode(response.body);
      if (value is Map) {
        return value.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
      }
      throw const FormatException('expected JSON object');
    } catch (error) {
      throw BrainbaseOfflineSyncException('$operation returned invalid JSON', cause: error);
    }
  }

  BrainbaseOfflineStatus _parseStatus(
    Map<String, dynamic> body, {
    required int httpStatus,
  }) {
    final session = _asMap(body['session']) ?? body;
    final id = _stringValue(session, const ['id', 'sessionId', 'session_id']);
    if (id == null || id.isEmpty) {
      throw BrainbaseOfflineSyncException('transcript session response omitted session id');
    }
    final status = _stringValue(session, const ['status']) ?? 'unknown';
    final chunkCount =
        _intValue(session, const ['chunkCount', 'chunk_count']) ?? (_asList(body['chunks'])?.length ?? 0);
    final chunks = _asList(body['chunks']) ?? const <dynamic>[];
    final ordered = chunks.whereType<Map>().toList()
      ..sort((a, b) =>
          (_intValue(_asMap(a), const ['sequence']) ?? 0).compareTo(_intValue(_asMap(b), const ['sequence']) ?? 0));
    final transcript = ordered
        .map((chunk) => _asMap(chunk)?['text'])
        .whereType<String>()
        .where((text) => text.trim().isNotEmpty)
        .join('\n');
    final recordedAtValue = _stringValue(session, const ['recordedAt', 'recorded_at']);
    return BrainbaseOfflineStatus(
      sessionId: id,
      status: status,
      chunkCount: chunkCount,
      recordedAt: recordedAtValue == null ? null : DateTime.tryParse(recordedAtValue),
      transcript: transcript,
      conversationId: _stringValue(session, const ['sourceConversationId', 'source_conversation_id']),
      httpStatus: httpStatus,
    );
  }

  void _validateResumableStatus(BrainbaseOfflineStatus status) {
    if (status.status.toLowerCase() == 'open') return;
    // Once a session has left open state, presign is rejected by the Worker.
    // Let finalize be retried for known lifecycle states and fail loudly for
    // an unknown state so the journal is retained for inspection.
    const closed = <String>{
      'queued',
      'ready_for_transcription',
      'transcribing',
      'processing',
      'finalizing',
      'finalized',
      'failed',
      'completed',
    };
    if (!closed.contains(status.status.toLowerCase())) {
      throw BrainbaseOfflineSyncException(
        'cannot resume session in unknown state: ${status.status}',
      );
    }
  }

  Future<void> _ensureJournal() {
    return _journalInitialization ??= _initializeJournal();
  }

  Future<void> _initializeJournal() async {
    final directory = _configuredJournalDirectory ??
        Directory(p.join((await getApplicationSupportDirectory()).path, 'brainbase_offline_sync'));
    await directory.create(recursive: true);
    _journalFile = File(p.join(directory.path, _journalName));
    if (!await _journalFile!.exists()) return;
    final text = await _journalFile!.readAsString();
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) throw const FormatException('journal root is not an object');
      final version = decoded['version'];
      if (version != _journalVersion) throw FormatException('unsupported journal version: $version');
      final batches = _asMap(decoded['batches']);
      if (batches == null) throw const FormatException('journal batches are missing');
      _journal = <String, _JournalBatch>{};
      for (final entry in batches.entries) {
        final value = _asMap(entry.value);
        if (value == null) throw const FormatException('invalid journal batch');
        final sessionId = value['sessionId'];
        final sequenceList = value['completedSequences'];
        if (sessionId is! String || sessionId.isEmpty || sequenceList is! List) {
          throw const FormatException('invalid journal batch fields');
        }
        _journal[entry.key] = _JournalBatch(
          sessionId: sessionId,
          completedSequences: sequenceList.whereType<num>().map((value) => value.toInt()).toSet(),
        );
      }
    } catch (error) {
      throw BrainbaseOfflineSyncException('offline sync journal is corrupt', cause: error);
    }
  }

  Future<void> _saveJournal() async {
    final journalFile = _journalFile;
    if (journalFile == null) throw StateError('journal is not initialized');
    final body = jsonEncode({
      'version': _journalVersion,
      'batches': {
        for (final entry in _journal.entries)
          entry.key: {
            'sessionId': entry.value.sessionId,
            'completedSequences': entry.value.completedSequences.toList()..sort(),
          },
      },
    });
    final temporary = File('${journalFile.path}.tmp');
    await temporary.writeAsString(body, flush: true);
    await temporary.rename(journalFile.path);
  }

  void _throwAuthCooldownIfActive(String operation) {
    final until = _authFailureUntil;
    if (until == null || DateTime.now().isAfter(until)) return;
    final seconds = math.max(1, until.difference(DateTime.now()).inSeconds);
    throw BrainbaseOfflineSyncException(
      '$operation skipped after recent authentication failure',
      statusCode: _authFailureStatus,
      retryAfterSeconds: seconds,
    );
  }

  void _reportProgress(
    BrainbaseOfflineUploadProgress? callback,
    int sent,
    int total,
    Stopwatch stopwatch,
  ) {
    if (callback == null) return;
    final elapsedSeconds = stopwatch.elapsedMicroseconds / Duration.microsecondsPerSecond;
    final double speed = elapsedSeconds <= 0 ? 0.0 : sent / 1024 / elapsedSeconds;
    callback(sent, total, speed);
  }

  Map<String, String> get _authHeaders => {
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
      };

  Uri _uri(String path) => _baseUri.resolve(path.startsWith('/') ? path.substring(1) : path);

  static Uri _parseBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError.value(value, 'baseUrl', 'must be an absolute URL');
    }
    final normalized = value.trim().endsWith('/') ? value.trim() : '${value.trim()}/';
    return Uri.parse(normalized);
  }

  static String _normalizeSessionId(String sessionId) =>
      sessionId.startsWith('cloudflare:') ? sessionId.substring('cloudflare:'.length) : sessionId;

  static int? _retryAfter(http.Response response) {
    final value = response.headers['retry-after'];
    return value == null ? null : int.tryParse(value);
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is! Map) return null;
    return value.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
  }

  static List<dynamic>? _asList(dynamic value) => value is List ? value : null;

  static String? _stringValue(Map<String, dynamic>? value, List<String> keys) {
    if (value == null) return null;
    for (final key in keys) {
      final candidate = value[key];
      if (candidate is String) return candidate;
    }
    return null;
  }

  static int? _intValue(Map<String, dynamic>? value, List<String> keys) {
    if (value == null) return null;
    for (final key in keys) {
      final candidate = value[key];
      if (candidate is num) return candidate.toInt();
      if (candidate is String) return int.tryParse(candidate);
    }
    return null;
  }
}

class _RecordingMetadata {
  const _RecordingMetadata({
    required this.file,
    required this.deviceId,
    required this.codec,
    required this.sampleRate,
    required this.channels,
    required this.frameSize,
    required this.recordedAt,
    required this.byteLength,
  });

  final File file;
  final String deviceId;
  final BleAudioCodec codec;
  final int sampleRate;
  final int channels;
  final int frameSize;
  final DateTime recordedAt;
  final int byteLength;
}

class _JournalBatch {
  _JournalBatch({required this.sessionId, required this.completedSequences});

  final String sessionId;
  Set<int> completedSequences;
}

class _DigestSink implements Sink<Digest> {
  Digest? _digest;

  Digest get value {
    final digest = _digest;
    if (digest == null) throw StateError('digest sink was not closed');
    return digest;
  }

  @override
  void add(Digest digest) {
    if (_digest != null) throw StateError('digest sink received more than one value');
    _digest = digest;
  }

  @override
  void close() {}
}
