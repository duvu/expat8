import 'dart:math';

import '../../api/backend_api_client.dart' show GameLeaderboard;
import '../../data/word_repository.dart';
import '../../logging/logger.dart';
import '../../models/vocabulary_word.dart';
import '../common/game_audio.dart';
import '../common/game_score_store.dart';
import '../common/game_settings.dart';
import '../game_storage.dart';
import 'word_blaster_learning.dart';
import 'word_blaster_mode.dart';
import 'word_blaster_stats.dart';

/// Everything Word Blaster screens need, built once by the games hub.
class WordBlasterContext {
  WordBlasterContext({
    required this.repository,
    required this.storage,
    required this.settings,
    required this.audio,
    required this.language,
    required this.learnerLevelIndex,
    this.speak,
    this.logger = const NoopLogger(),
    this.onRoundFinished,
    this.fetchLeaderboard,
    Random Function()? randomFactory,
    Future<List<VocabularyWord>> Function()? loadWords,
  })  : randomFactory = randomFactory ?? Random.new,
        _loadWords = loadWords;

  final WordRepository repository;
  final GameStorage storage;
  final GameSettings settings;
  final GameAudio audio;

  /// Active learning language (`en`, `zh`, ...).
  final String language;

  /// Learner level index (A1/HSK1 = 0).
  final int learnerLevelIndex;

  /// Text-to-speech for listening prompts; null disables Listening mode.
  final Future<void> Function(String text, String languageCode)? speak;
  final Logger logger;

  /// Called after each finished round (e.g. to queue it for backend sync).
  final void Function(WordBlasterRoundSummary round)? onRoundFinished;

  /// Weekly global leaderboard; returns null when not signed in. Throws when
  /// offline (the board screen then shows the cached copy).
  final Future<GameLeaderboard?> Function(
      {required String game, required String mode})? fetchLeaderboard;
  final Random Function() randomFactory;
  final Future<List<VocabularyWord>> Function()? _loadWords;

  late final GameScoreStore scores =
      GameScoreStore(storage, gameId: 'word_blaster');
  late final WordBlasterStatsStore stats = WordBlasterStatsStore(storage);
  late final WordBlasterLearning learning =
      WordBlasterLearning(repository: repository, logger: logger);

  static const _lastModeKey = 'games.word_blaster.last_mode';

  Future<List<VocabularyWord>> loadWords() =>
      _loadWords?.call() ?? repository.database.wordsForLanguage(language);

  String get ttsLanguageCode => switch (language) {
        'zh' => 'zh-CN',
        'vi' => 'vi-VN',
        _ => 'en-US',
      };

  bool isUnlocked(WordBlasterMode mode) =>
      learnerLevelIndex >= mode.minLevelIndex;
  bool isAvailable(WordBlasterMode mode) =>
      mode != WordBlasterMode.listening || speak != null;

  Future<WordBlasterMode?> lastMode() async {
    final name = await storage.read(_lastModeKey);
    return name == null ? null : WordBlasterMode.fromName(name);
  }

  Future<void> saveLastMode(WordBlasterMode mode) =>
      storage.write(_lastModeKey, mode.name);
}
