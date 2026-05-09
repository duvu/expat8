import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages local audio files for speaking attempts.
///
/// Naming convention: `speaking_<attemptId>_<epochMs>.m4a`
/// Storage: `<appDocumentsDir>/speaking_audio/`
///
/// Audio paths are kept strictly local — they must NEVER appear in:
///   • backend API request bodies
///   • mobile application logs
///   • sync queue payloads
class AudioFileManager {
  static const _subdir = 'speaking_audio';

  /// File extension used for all speaking recordings.
  static const extension = 'm4a';

  /// Retention window: files older than this are eligible for cleanup.
  static const retentionDays = 30;

  /// Returns the directory where speaking audio is stored, creating it if
  /// needed.
  Future<Directory> get _dir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _subdir));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Returns the full path for a new recording identified by [attemptId].
  /// The caller should treat this path as opaque and local-only.
  Future<String> pathForAttempt(String attemptId) async {
    final dir = await _dir;
    final ms = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, 'speaking_${attemptId}_$ms.$extension');
  }

  /// Deletes the local file at [localAudioPath].
  /// Returns true if the file existed and was deleted.
  Future<bool> deleteOne(String localAudioPath) async {
    final file = File(localAudioPath);
    if (!file.existsSync()) return false;
    await file.delete();
    return true;
  }

  /// Deletes all local speaking recordings.
  Future<int> deleteAll() async {
    final dir = await _dir;
    int count = 0;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.$extension')) {
        await entity.delete();
        count++;
      }
    }
    return count;
  }

  /// Deletes files older than [retentionDays] days.
  /// Returns the number of files deleted.
  Future<int> runRetentionCleanup() async {
    final dir = await _dir;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: retentionDays))
        .millisecondsSinceEpoch;
    int count = 0;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.$extension')) {
        final stat = entity.statSync();
        if (stat.modified.millisecondsSinceEpoch < cutoff) {
          await entity.delete();
          count++;
        }
      }
    }
    return count;
  }

  /// Returns the list of all locally stored audio files.
  Future<List<File>> listAll() async {
    final dir = await _dir;
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.$extension')) {
        files.add(entity);
      }
    }
    return files;
  }
}
