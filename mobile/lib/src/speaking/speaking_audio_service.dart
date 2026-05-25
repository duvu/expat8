import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'audio_file_manager.dart';

/// Result of a permission check / request.
enum MicPermissionStatus { granted, denied, permanentlyDenied }

/// Abstracts all audio I/O for the speaking feature.
///
/// UI and repository code depend on this interface only — never on plugin APIs
/// directly — so the implementation can be swapped or mocked in tests.
abstract interface class ISpeakingAudioService {
  /// Returns the current microphone permission status without asking.
  Future<MicPermissionStatus> checkMicPermission();

  /// Requests microphone permission at the moment recording should start.
  /// Shows system prompt only the first time.
  Future<MicPermissionStatus> requestMicPermission();

  /// Speaks [text] via TTS in [languageCode] (default: "en-US").
  Future<void> speakSample(String text, {String languageCode = 'en-US'});

  /// Stops any in-progress TTS playback.
  Future<void> stopSample();

  /// Begins recording into a new file managed by [AudioFileManager].
  /// Returns the opaque [attemptId] that was used for the file name.
  /// Throws [StateError] if a recording is already in progress.
  Future<String> startRecording(String attemptId);

  /// Stops the current recording.
  /// Returns the local file path (for immediate playback only — must NOT be
  /// included in any backend payload).
  Future<String?> stopRecording();

  /// Plays back the local file identified by [localAudioPath].
  Future<void> playLocal(String localAudioPath);

  /// Stops local playback.
  Future<void> stopPlayback();

  /// Releases underlying resources. Call when the speaking session is closed.
  Future<void> dispose();
}

/// Production implementation backed by flutter_tts + record + just_audio.
class SpeakingAudioService implements ISpeakingAudioService {
  SpeakingAudioService({required AudioFileManager fileManager})
      : _fileManager = fileManager;

  final AudioFileManager _fileManager;
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _recording = false;

  // ---------- permission ----------

  @override
  Future<MicPermissionStatus> checkMicPermission() async {
    final status = await Permission.microphone.status;
    return _toMicStatus(status);
  }

  @override
  Future<MicPermissionStatus> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return _toMicStatus(status);
  }

  static MicPermissionStatus _toMicStatus(PermissionStatus s) {
    if (s.isGranted) return MicPermissionStatus.granted;
    if (s.isPermanentlyDenied) return MicPermissionStatus.permanentlyDenied;
    return MicPermissionStatus.denied;
  }

  // ---------- TTS ----------

  @override
  Future<void> speakSample(String text, {String languageCode = 'en-US'}) async {
    await _tts.setLanguage(languageCode);
    await _tts.setSpeechRate(0.85);
    await _tts.speak(text);
  }

  @override
  Future<void> stopSample() async {
    await _tts.stop();
  }

  // ---------- recording ----------

  @override
  Future<String> startRecording(String attemptId) async {
    if (_recording) {
      throw StateError('Recording already in progress');
    }
    final path = await _fileManager.pathForAttempt(attemptId);
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _recording = true;
    return attemptId;
  }

  @override
  Future<String?> stopRecording() async {
    if (!_recording) return null;
    _recording = false;
    // Returns the file path written by the recorder.
    final path = await _recorder.stop();
    return path; // local-only — caller must NOT include in API payloads
  }

  // ---------- playback ----------

  @override
  Future<void> playLocal(String localAudioPath) async {
    await _player.setFilePath(localAudioPath);
    await _player.play();
  }

  @override
  Future<void> stopPlayback() async {
    await _player.stop();
  }

  // ---------- lifecycle ----------

  @override
  Future<void> dispose() async {
    await _tts.stop();
    if (_recording) {
      await _recorder.stop();
      _recording = false;
    }
    await _recorder.dispose();
    await _player.dispose();
  }
}
