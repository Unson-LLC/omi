import 'package:omi/models/sync_state.dart';
import 'package:omi/utils/sync/offline_processing_display.dart';

/// Builds the secondary line under the offline sync status card.
class SyncCardProgressLine {
  const SyncCardProgressLine._();

  static String? subtitle({
    required SyncPhase phase,
    required int? currentFile,
    required int? totalFiles,
    required String Function(int processed, int total) counterLabel,
    double? progress,
    int? uploadedBytes,
    int? totalBytesToUpload,
    String? speedSuffix,
  }) {
    if (phase != SyncPhase.downloadingFromDevice && phase != SyncPhase.uploadingToCloud) {
      return speedSuffix;
    }

    var current = currentFile ?? 0;
    // Device download reports the 1-based active file index; upload uses completed count.
    if (phase == SyncPhase.downloadingFromDevice && current > 0) {
      current -= 1;
    }

    final normalized = OfflineProcessingDisplay.normalizeCounts(
      current: current,
      total: totalFiles ?? 0,
    );
    final percent = _transferPercent(
      phase: phase,
      progress: progress,
      uploadedBytes: uploadedBytes,
      totalBytesToUpload: totalBytesToUpload,
      fallbackProcessed: normalized.processed,
      fallbackTotal: normalized.total,
    );
    if (normalized.total <= 0 && percent == null) {
      return speedSuffix;
    }

    final parts = <String>[];
    if (normalized.total > 0) {
      parts.add(counterLabel(normalized.processed, normalized.total));
    }
    if (percent != null) {
      parts.add('$percent%');
    }
    if (speedSuffix != null && speedSuffix.isNotEmpty) {
      parts.add(speedSuffix);
    }
    return parts.join(' · ');
  }

  static int? _transferPercent({
    required SyncPhase phase,
    required double? progress,
    required int? uploadedBytes,
    required int? totalBytesToUpload,
    required int fallbackProcessed,
    required int fallbackTotal,
  }) {
    // Cloud uploads can report byte counts independently of completed files.
    // Prefer those counts when present so a large file does not sit at the
    // previous file boundary for the entire multipart transfer.
    if (phase == SyncPhase.uploadingToCloud &&
        uploadedBytes != null &&
        totalBytesToUpload != null &&
        totalBytesToUpload > 0) {
      final fraction = (uploadedBytes / totalBytesToUpload).clamp(0.0, 1.0).toDouble();
      return (fraction * 100).round();
    }

    // Device callbacks report byte-based progress through the percentage
    // argument. Keep that value independent from completed-file counters.
    if (progress != null) {
      return (progress.clamp(0.0, 1.0).toDouble() * 100).round();
    }

    if (fallbackTotal <= 0) {
      return null;
    }
    return OfflineProcessingDisplay.completionPercent(
      processed: fallbackProcessed,
      total: fallbackTotal,
    );
  }

  static String? serverProcessingSubtitle({
    required int processed,
    required int total,
    required String Function(int processed, int total) counterLabel,
  }) {
    final normalized = OfflineProcessingDisplay.normalizeCounts(current: processed, total: total);
    if (normalized.total <= 0) {
      return null;
    }
    final percent = OfflineProcessingDisplay.completionPercent(
      processed: normalized.processed,
      total: normalized.total,
    );
    return '${counterLabel(normalized.processed, normalized.total)} · $percent%';
  }
}
