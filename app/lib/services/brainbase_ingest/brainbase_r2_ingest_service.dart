import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:omi/backend/schema/bt_device/bt_device.dart';
import 'package:omi/services/audio_sources/audio_source.dart';
import 'package:omi/services/brainbase_ingest/brainbase_audio_contract.dart';
import 'package:omi/utils/audio/audio_transcoder.dart';
import 'package:omi/utils/audio/wav_bytes.dart';
import 'package:omi/utils/logger.dart';

class BrainbaseR2IngestService {
  BrainbaseR2IngestService._({
    String baseUrl = const String.fromEnvironment('BRAINBASE_INGEST_URL'),
    String token = const String.fromEnvironment('BRAINBASE_INGEST_TOKEN'),
    http.Client? client,
    Future<BrainbaseR2UploadQueue> Function()? openQueue,
    Duration? retryInterval = const Duration(seconds: 15),
  })  : _baseUrl = baseUrl,
        _token = token,
        _http = client ?? http.Client(),
        _openQueue = openQueue,
        _retryInterval = retryInterval;

  /// A service over a queue in [directory], with no retry timer.
  @visibleForTesting
  factory BrainbaseR2IngestService.forTesting({
    required String baseUrl,
    required String token,
    required http.Client client,
    required Directory directory,
  }) {
    return BrainbaseR2IngestService._(
      baseUrl: baseUrl,
      token: token,
      client: client,
      openQueue: () => BrainbaseR2UploadQueue.openAt(
        directory: directory,
        baseUrl: baseUrl,
        token: token,
        client: client,
      ),
      retryInterval: null,
    );
  }

  static final instance = BrainbaseR2IngestService._();
  static const _chunkSeconds = 30;

  final String _baseUrl;
  final String _token;
  final http.Client _http;
  final Future<BrainbaseR2UploadQueue> Function()? _openQueue;
  final Duration? _retryInterval;
  final BytesBuilder _pcm = BytesBuilder(copy: false);
  Future<void> _serial = Future.value();
  Timer? _retryTimer;
  IAudioTranscoder? _toPcm;
  BrainbaseR2UploadQueue? _queue;
  String? _sessionId;
  int _sequence = 0;
  int _sampleRate = 16000;
  final int _channels = brainbaseChannels;

  bool get enabled => _baseUrl.isNotEmpty && _token.isNotEmpty;

  /// Reopens the durable queue after app startup, without creating a recording
  /// session. Only the local queue open runs on [_serial]; the network drain
  /// runs beside it, so a slow or hanging upload never delays [start].
  Future<void> resumePendingUploads() {
    final operation = _serial.then((_) async {
      if (!enabled) return;
      await _ensureQueueReady();
      unawaited(_queue!.drain());
    });
    _serial = operation.catchError((Object error, StackTrace stack) {
      Logger.error(
        '[BrainbaseIngest] pending upload recovery failed: $error\n$stack',
      );
    });
    return _serial;
  }

  Future<void> start({required BleAudioCodec codec, required String deviceId}) {
    final operation = _serial.then((_) async {
      if (!enabled || _sessionId != null) return;
      await _ensureQueueReady();
      // Not awaited: pending uploads must not hold up a new recording session.
      unawaited(_queue!.drain());
      late final String sourceCodec;
      try {
        _sampleRate = brainbaseSampleRate(codec);
        sourceCodec = brainbaseCodecName(codec);
      } on UnsupportedError {
        Logger.error('[BrainbaseIngest] unsupported codec: $codec');
        return;
      }
      _toPcm = AudioTranscoderFactory.createToRawPcm(
        sourceCodec: codec,
        sampleRate: _sampleRate,
        channels: _channels,
      );
      final sessionId = await _queue!.createSession(
        deviceId: deviceId,
        sourceCodec: sourceCodec,
        sampleRate: _sampleRate,
        channels: _channels,
        chunkDurationSeconds: _chunkSeconds,
      );
      await _queue!.markSessionActive(sessionId);
      _sessionId = sessionId;
      _sequence = 0;
      Logger.debug('[BrainbaseIngest] session started: $_sessionId');
    });
    _serial = operation.catchError((Object error, StackTrace stack) {
      Logger.error('[BrainbaseIngest] start failed: $error\n$stack');
    });
    return operation;
  }

  Future<void> _ensureQueueReady() async {
    _queue ??= await (_openQueue?.call() ??
        BrainbaseR2UploadQueue.open(
          baseUrl: _baseUrl,
          token: _token,
          client: _http,
        ));
    final retryInterval = _retryInterval;
    if (retryInterval != null) {
      _retryTimer ??= Timer.periodic(
        retryInterval,
        (_) => unawaited(_queue?.drain()),
      );
    }
  }

  Future<void> addFrames(List<WalFrame> frames) {
    return _serial = _serial.then((_) async {
      if (!enabled || _sessionId == null || _toPcm == null) return;
      for (final frame in frames) {
        try {
          _pcm.add(_toPcm!.transcode(Uint8List.fromList(frame.payload)));
        } catch (error) {
          Logger.debug(
            '[BrainbaseIngest] skipped undecodable frame: $error',
          );
        }
      }
      final targetBytes = _sampleRate * _channels * 2 * _chunkSeconds;
      if (_pcm.length >= targetBytes) await _flushChunk();
    }).catchError((Object error, StackTrace stack) {
      Logger.error(
        '[BrainbaseIngest] frame handling failed: $error\n$stack',
      );
    });
  }

  Future<void> stop() {
    return _serial = _serial.then((_) async {
      if (!enabled || _sessionId == null || _queue == null) return;
      if (_pcm.length > 0) await _flushChunk();
      await _queue!.markForFinalize(_sessionId!);
      unawaited(_queue!.drain());
      Logger.debug('[BrainbaseIngest] session stopped: $_sessionId');
      _sessionId = null;
      _toPcm = null;
      _sequence = 0;
    }).catchError((Object error, StackTrace stack) {
      Logger.error(
        '[BrainbaseIngest] stop failed; queue retained: $error\n$stack',
      );
    });
  }

  Future<void> _flushChunk() async {
    final sessionId = _sessionId;
    if (sessionId == null || _queue == null || _pcm.length == 0) return;
    final pcm = _pcm.takeBytes();
    final wav = WavBytes.fromPcm(
      pcm,
      sampleRate: _sampleRate,
      numChannels: _channels,
    ).asBytes();
    await _queue!.enqueue(
      sessionId: sessionId,
      sequence: _sequence++,
      bytes: wav,
    );
    unawaited(_queue!.drain());
  }
}

@visibleForTesting
class BrainbaseR2UploadQueue {
  BrainbaseR2UploadQueue._(
    this._directory,
    this._manifest,
    this._baseUrl,
    this._token,
    this._client,
    this._beforeDeleteUploadedFile,
  );

  static const _requestTimeout = Duration(seconds: 15);
  static const _uploadTimeout = Duration(seconds: 60);

  final Directory _directory;
  final File _manifest;
  final String _baseUrl;
  final String _token;
  final http.Client _client;
  final Future<void> Function(File file)? _beforeDeleteUploadedFile;
  final List<Map<String, dynamic>> _items = [];

  /// Items whose audio is gone locally and was never uploaded. They are kept
  /// out of [_items] so one lost file cannot stall every later chunk.
  final List<Map<String, dynamic>> _corruptedItems = [];
  final Set<String> _finalizeSessions = {};

  /// Sessions whose finalize the server refused with a permanent 4xx.
  final Set<String> _rejectedFinalizeSessions = {};
  String? _activeSessionId;
  bool _activeSessionHasChunks = false;
  Future<void> _saveSerial = Future.value();
  bool _draining = false;
  bool _drainRequested = false;

  static Future<BrainbaseR2UploadQueue> open({
    required String baseUrl,
    required String token,
    required http.Client client,
  }) async {
    final root = await getApplicationSupportDirectory();
    return openAt(
      directory: Directory('${root.path}/brainbase_r2_ingest'),
      baseUrl: baseUrl,
      token: token,
      client: client,
    );
  }

  @visibleForTesting
  static Future<BrainbaseR2UploadQueue> openAt({
    required Directory directory,
    required String baseUrl,
    required String token,
    required http.Client client,
    Future<void> Function(File file)? beforeDeleteUploadedFile,
  }) async {
    await directory.create(recursive: true);
    final queue = BrainbaseR2UploadQueue._(
      directory,
      File('${directory.path}/manifest.json'),
      baseUrl,
      token,
      client,
      beforeDeleteUploadedFile,
    );
    await queue._load();
    await queue._collectOrphanedAudio();
    await queue._recoverOrphanedSessions();
    return queue;
  }

  @visibleForTesting
  int get pendingItemCount => _items.length;

  @visibleForTesting
  int get corruptedItemCount => _corruptedItems.length;

  @visibleForTesting
  bool isFinalizeRejected(String sessionId) => _rejectedFinalizeSessions.contains(sessionId);

  @visibleForTesting
  bool isFinalizePending(String sessionId) => _finalizeSessions.contains(sessionId);

  Future<void> markSessionActive(String sessionId) async {
    _activeSessionId = sessionId;
    _activeSessionHasChunks = false;
    await _save();
  }

  Map<String, String> get _headers => {
        'authorization': 'Bearer $_token',
        'content-type': 'application/json',
      };

  Future<String> createSession({
    required String deviceId,
    required String sourceCodec,
    required int sampleRate,
    required int channels,
    required int chunkDurationSeconds,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/v1/upload-sessions'),
          headers: _headers,
          body: jsonEncode({
            'deviceId': deviceId,
            'sourceCodec': sourceCodec,
            'sampleRate': sampleRate,
            'channels': channels,
            'chunkDurationSeconds': chunkDurationSeconds,
          }),
        )
        .timeout(_requestTimeout);
    final value = _decode(response);
    return value['sessionId'] as String;
  }

  Future<void> enqueue({
    required String sessionId,
    required int sequence,
    required Uint8List bytes,
  }) async {
    final name = '${sessionId}_${sequence.toString().padLeft(8, '0')}.wav';
    final file = File('${_directory.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    _items.add({
      'sessionId': sessionId,
      'sequence': sequence,
      'path': name,
      'sha256': sha256.convert(bytes).toString(),
      'byteLength': bytes.length,
    });
    if (_activeSessionId == sessionId) _activeSessionHasChunks = true;
    await _save();
  }

  Future<void> markForFinalize(String sessionId) async {
    if (_activeSessionId == sessionId) {
      final hasChunks = _activeSessionHasChunks;
      _activeSessionId = null;
      _activeSessionHasChunks = false;
      if (hasChunks) _finalizeSessions.add(sessionId);
    } else {
      _finalizeSessions.add(sessionId);
    }
    await _save();
  }

  /// Uploads queued chunks, then finalizes stopped sessions.
  ///
  /// A call made while a drain is running is not lost: the running drain makes
  /// one more pass once it finishes cleanly, so a chunk enqueued or a session
  /// stopped mid-drain is sent without waiting for the retry timer. A drain
  /// that stops on an error leaves the rest to the timer.
  Future<void> drain() async {
    if (_draining) {
      _drainRequested = true;
      return;
    }
    _draining = true;
    try {
      do {
        _drainRequested = false;
        if (!await _drainOnce()) return;
      } while (_drainRequested);
    } catch (error) {
      Logger.debug('[BrainbaseIngest] upload paused; will retry: $error');
    } finally {
      _draining = false;
      _drainRequested = false;
    }
  }

  /// One pass over the queue. Returns false when it stopped on an item it must
  /// not touch; network and server errors throw.
  Future<bool> _drainOnce() async {
    while (_items.isNotEmpty) {
      final item = _items.first;
      final storedPath = item['path'];
      if (storedPath is! String) {
        Logger.error('[BrainbaseIngest] queued file path is invalid');
        return false;
      }
      final file = _resolveQueuedFile(storedPath);
      if (file == null) {
        Logger.error('[BrainbaseIngest] queued file path rejected');
        return false;
      }
      final fileType = await FileSystemEntity.type(
        file.path,
        followLinks: false,
      );
      if (fileType == FileSystemEntityType.notFound) {
        await _recoverMissingFile(item);
        continue;
      }
      if (fileType != FileSystemEntityType.file) {
        Logger.error('[BrainbaseIngest] queued file is not a regular file: ${file.path}');
        return false;
      }
      final presign = await _presign(item);
      if (presign['alreadyUploaded'] != true) {
        final bytes = await file.readAsBytes();
        final put = await _client
            .put(
              Uri.parse(presign['putUrl'] as String),
              headers: {
                'content-type': 'audio/wav',
                'x-amz-meta-sha256': item['sha256'] as String,
              },
              body: bytes,
            )
            .timeout(_uploadTimeout);
        if (put.statusCode < 200 || put.statusCode >= 300) {
          throw HttpException('R2 PUT failed: ${put.statusCode}');
        }
      }
      await _complete(item);
      // Persist the removal before deleting the audio. A crash in between
      // leaves only an unreferenced file, which the next open collects; the
      // reverse order would leave a manifest item whose audio is gone.
      _items.remove(item);
      await _save();
      await _beforeDeleteUploadedFile?.call(file);
      try {
        await file.delete();
      } on FileSystemException catch (error) {
        Logger.debug('[BrainbaseIngest] uploaded file not deleted; collected on next start: $error');
      }
    }
    for (final sessionId in _finalizeSessions.toList()) {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/upload-sessions/$sessionId/finalize'),
            headers: _headers,
          )
          .timeout(_requestTimeout);
      try {
        _decode(response);
      } on BrainbaseIngestApiException catch (error) {
        if (!error.isPermanent) rethrow;
        // Retrying a refused finalize cannot succeed and would block the
        // sessions behind it. Keep the session id for diagnosis.
        _finalizeSessions.remove(sessionId);
        _rejectedFinalizeSessions.add(sessionId);
        await _save();
        Logger.error('[BrainbaseIngest] finalize refused; session set aside: $sessionId (${error.statusCode})');
        continue;
      }
      _finalizeSessions.remove(sessionId);
      await _save();
    }
    return true;
  }

  /// Settles a queue item whose local audio file is missing.
  ///
  /// If the server already holds the chunk, completing it again is idempotent
  /// and recovers the item. Otherwise the audio is lost: the item is set aside
  /// in [_corruptedItems] so the rest of the queue keeps moving.
  ///
  /// A permanent 4xx from presign or complete also sets the item aside: with no
  /// local audio there is nothing a retry could send. Retryable failures throw
  /// and keep the item for the next drain.
  Future<void> _recoverMissingFile(Map<String, dynamic> item) async {
    try {
      final presign = await _presign(item);
      if (presign['alreadyUploaded'] == true) {
        await _complete(item);
        _items.remove(item);
        await _save();
        Logger.debug('[BrainbaseIngest] recovered an uploaded chunk whose file was missing');
        return;
      }
    } on BrainbaseIngestApiException catch (error) {
      if (!error.isPermanent) rethrow;
    }
    _items.remove(item);
    _corruptedItems.add(item);
    await _save();
    Logger.error(
      '[BrainbaseIngest] queued audio missing and not uploaded; set aside: '
      '${item['sessionId']}#${item['sequence']}',
    );
  }

  Future<Map<String, dynamic>> _presign(Map<String, dynamic> item) async {
    final response = await _client
        .post(
          Uri.parse(
            '$_baseUrl/v1/upload-sessions/${item['sessionId']}/chunks/${item['sequence']}/presign',
          ),
          headers: _headers,
          body: jsonEncode({
            'sha256': item['sha256'],
            'byteLength': item['byteLength'],
            'contentType': 'audio/wav',
          }),
        )
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<void> _complete(Map<String, dynamic> item) async {
    final response = await _client
        .post(
          Uri.parse(
            '$_baseUrl/v1/upload-sessions/${item['sessionId']}/chunks/${item['sequence']}/complete',
          ),
          headers: _headers,
        )
        .timeout(_requestTimeout);
    _decode(response);
  }

  /// Deletes queue `.wav` files that no manifest item refers to.
  ///
  /// Runs once at open, before this process enqueues anything, so every
  /// unreferenced file is left over from an earlier process: audio deleted
  /// after its item was saved away, or written before a crash. Only regular
  /// files directly inside the queue directory are touched.
  Future<void> _collectOrphanedAudio() async {
    final referenced = <String>{};
    for (final item in [..._items, ..._corruptedItems]) {
      final storedPath = item['path'];
      if (storedPath is! String) continue;
      final file = _resolveQueuedFile(storedPath);
      if (file != null) referenced.add(_basename(file.path));
    }
    await for (final entity in _directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = _basename(entity.path);
      if (!name.endsWith('.wav') || referenced.contains(name)) continue;
      try {
        await entity.delete();
      } on FileSystemException catch (error) {
        Logger.debug('[BrainbaseIngest] orphaned audio not deleted: $error');
      }
    }
  }

  static String _basename(String path) => path.replaceAll('\\', '/').split('/').last;

  File? _resolveQueuedFile(String storedPath) {
    final normalized = storedPath.replaceAll('\\', '/');
    final isAbsolute = normalized.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(normalized);
    final basename = normalized.split('/').last;
    if (basename.isEmpty || basename == '.' || basename == '..') return null;
    if (!isAbsolute && basename != normalized) return null;
    return File('${_directory.path}/$basename');
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      Object? error;
      try {
        final value = jsonDecode(response.body);
        if (value is Map<String, dynamic>) error = value['error'];
      } on FormatException {
        // Error bodies are not always JSON (proxies, gateways).
      }
      throw BrainbaseIngestApiException(response.statusCode, error);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _load() async {
    if (!await _manifest.exists()) return;
    final value = jsonDecode(await _manifest.readAsString()) as Map<String, dynamic>;
    _items.addAll(
      (value['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
    );
    _finalizeSessions.addAll(
      (value['finalizeSessions'] as List<dynamic>? ?? []).cast<String>(),
    );
    _corruptedItems.addAll(
      (value['corruptedItems'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
    );
    _rejectedFinalizeSessions.addAll(
      (value['rejectedFinalizeSessions'] as List<dynamic>? ?? []).cast<String>(),
    );
    final activeSessionId = value['activeSessionId'];
    if (activeSessionId is String && activeSessionId.isNotEmpty) {
      _activeSessionId = activeSessionId;
      _activeSessionHasChunks = value['activeSessionHasChunks'] == true;
    }
  }

  Future<void> _recoverOrphanedSessions() async {
    final orphanedSessions = <String>{};
    final activeSessionId = _activeSessionId;
    if (activeSessionId != null && _activeSessionHasChunks) {
      orphanedSessions.add(activeSessionId);
    }
    for (final item in _items) {
      final sessionId = item['sessionId'];
      if (sessionId is String && sessionId.isNotEmpty) {
        orphanedSessions.add(sessionId);
      }
    }
    if (orphanedSessions.isEmpty && activeSessionId == null) return;
    _finalizeSessions.addAll(orphanedSessions);
    _activeSessionId = null;
    _activeSessionHasChunks = false;
    await _save();
  }

  Future<void> _save() async {
    final snapshot = jsonEncode({
      'items': _items,
      'corruptedItems': _corruptedItems,
      'finalizeSessions': _finalizeSessions.toList(),
      'rejectedFinalizeSessions': _rejectedFinalizeSessions.toList(),
      'activeSessionId': _activeSessionId,
      'activeSessionHasChunks': _activeSessionHasChunks,
    });
    _saveSerial = _saveSerial.catchError((_) {}).then((_) async {
      final temporary = File('${_manifest.path}.tmp');
      await temporary.writeAsString(snapshot, flush: true);
      await temporary.rename(_manifest.path);
    });
    await _saveSerial;
  }
}

/// A non-2xx answer from the Brainbase ingest API.
class BrainbaseIngestApiException extends HttpException {
  BrainbaseIngestApiException(this.statusCode, Object? error) : super('ingest API $statusCode: $error');

  final int statusCode;

  /// A 4xx the same request cannot fix by retrying. Auth, timeout and rate
  /// limit answers stay retryable: they depend on server state, not the request.
  bool get isPermanent =>
      statusCode >= 400 && statusCode < 500 && !const {401, 403, 408, 425, 429}.contains(statusCode);
}
