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
  BrainbaseR2IngestService._();

  static final instance = BrainbaseR2IngestService._();
  static const _baseUrl = String.fromEnvironment('BRAINBASE_INGEST_URL');
  static const _token = String.fromEnvironment('BRAINBASE_INGEST_TOKEN');
  static const _chunkSeconds = 30;

  final http.Client _http = http.Client();
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

  Future<void> start({required BleAudioCodec codec, required String deviceId}) {
    final operation = _serial.then((_) async {
      if (!enabled || _sessionId != null) return;
      _queue ??= await BrainbaseR2UploadQueue.open(
        baseUrl: _baseUrl,
        token: _token,
        client: _http,
      );
      _retryTimer ??= Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(_queue?.drain()),
      );
      await _queue!.drain();
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
  );

  static const _requestTimeout = Duration(seconds: 15);
  static const _uploadTimeout = Duration(seconds: 60);

  final Directory _directory;
  final File _manifest;
  final String _baseUrl;
  final String _token;
  final http.Client _client;
  final List<Map<String, dynamic>> _items = [];
  final Set<String> _finalizeSessions = {};
  String? _activeSessionId;
  bool _activeSessionHasChunks = false;
  Future<void> _saveSerial = Future.value();
  bool _draining = false;

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
  }) async {
    await directory.create(recursive: true);
    final queue = BrainbaseR2UploadQueue._(
      directory,
      File('${directory.path}/manifest.json'),
      baseUrl,
      token,
      client,
    );
    await queue._load();
    await queue._recoverOrphanedSessions();
    return queue;
  }

  @visibleForTesting
  int get pendingItemCount => _items.length;

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

  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_items.isNotEmpty) {
        final item = _items.first;
        final storedPath = item['path'];
        if (storedPath is! String) {
          Logger.error('[BrainbaseIngest] queued file path is invalid');
          return;
        }
        final file = _resolveQueuedFile(storedPath);
        if (file == null) {
          Logger.error('[BrainbaseIngest] queued file path rejected');
          return;
        }
        final fileType = await FileSystemEntity.type(
          file.path,
          followLinks: false,
        );
        if (fileType != FileSystemEntityType.file) {
          Logger.error('[BrainbaseIngest] queued file missing: ${file.path}');
          return;
        }
        final presignResponse = await _client
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
        final presign = _decode(presignResponse);
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
        final complete = await _client
            .post(
              Uri.parse(
                '$_baseUrl/v1/upload-sessions/${item['sessionId']}/chunks/${item['sequence']}/complete',
              ),
              headers: _headers,
            )
            .timeout(_requestTimeout);
        _decode(complete);
        await file.delete();
        _items.removeAt(0);
        await _save();
      }
      for (final sessionId in _finalizeSessions.toList()) {
        final response = await _client
            .post(
              Uri.parse('$_baseUrl/v1/upload-sessions/$sessionId/finalize'),
              headers: _headers,
            )
            .timeout(_requestTimeout);
        _decode(response);
        _finalizeSessions.remove(sessionId);
        await _save();
      }
    } catch (error) {
      Logger.debug('[BrainbaseIngest] upload paused; will retry: $error');
    } finally {
      _draining = false;
    }
  }

  File? _resolveQueuedFile(String storedPath) {
    final normalized = storedPath.replaceAll('\\', '/');
    final isAbsolute = normalized.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(normalized);
    final basename = normalized.split('/').last;
    if (basename.isEmpty || basename == '.' || basename == '..') return null;
    if (!isAbsolute && basename != normalized) return null;
    return File('${_directory.path}/$basename');
  }

  Map<String, dynamic> _decode(http.Response response) {
    final value = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'ingest API ${response.statusCode}: ${value['error']}',
      );
    }
    return value;
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
      'finalizeSessions': _finalizeSessions.toList(),
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
