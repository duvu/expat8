import 'dart:math';

import '../../curriculum/skill_answer_sink.dart';
import '../common/game_audio.dart';
import '../common/game_score_store.dart';
import '../common/game_settings.dart';
import '../common/game_story.dart';
import '../common/game_theme.dart';
import '../english/english_quiz.dart';
import '../game_storage.dart';
import '../math/math_problem.dart';
import '../math/math_round.dart';
import '../math/math_skills.dart';
import 'quiz_core.dart';
import 'quiz_round.dart';
import 'quiz_skills.dart';

enum QuizSubject {
  math(title: 'Math', audience: 'Grades 1–9', levels: MathLevel.values),
  english(
      title: 'English', audience: 'Grades 6–9', levels: EnglishLevel.values);

  const QuizSubject(
      {required this.title, required this.audience, required this.levels});

  final String title;

  /// Who the subject's levels are for, e.g. "Grades 6–9".
  final String audience;
  final List<QuizLevel> levels;

  QuizLevel levelFromId(String? id) {
    // A plain loop: [levels] is a List<MathLevel>/<EnglishLevel> at runtime,
    // so firstWhere's orElse cannot return the wider QuizLevel type.
    for (final level in levels) {
      if (level.id == id) return level;
    }
    return levels.first;
  }
}

/// Every quiz game. [id] namespaces scores and preferences.
enum QuizGameKind {
  blaster(
      id: 'math_blaster', title: 'Number Blaster', subject: QuizSubject.math),
  race(id: 'math_race', title: 'Math Race', subject: QuizSubject.math),
  moles(id: 'math_moles', title: 'Whack-a-Number', subject: QuizSubject.math),
  tower(id: 'math_tower', title: 'Number Tower', subject: QuizSubject.math),
  duel(id: 'math_duel', title: 'Math Duel', subject: QuizSubject.math),
  grammarBlaster(
      id: 'english_blaster',
      title: 'Grammar Blaster',
      subject: QuizSubject.english),
  wordWhack(
      id: 'english_whack', title: 'Word Whack', subject: QuizSubject.english),
  englishDuel(
      id: 'english_duel', title: 'English Duel', subject: QuizSubject.english),
  sentenceBuilder(
      id: 'english_sentences',
      title: 'Sentence Builder',
      subject: QuizSubject.english);

  const QuizGameKind(
      {required this.id, required this.title, required this.subject});

  final String id;
  final String title;
  final QuizSubject subject;
}

/// Everything the quiz games share: storage, sound, story progress, the
/// per-subject skill trackers and per-game level/theme preferences.
class QuizGameContext {
  QuizGameContext({
    required this.storage,
    required this.settings,
    required this.audio,
    this.skillSink,
    Random Function()? randomFactory,
  })  : randomFactory = randomFactory ?? Random.new,
        mathSkills = MathSkillTracker(storage),
        englishSkills = EnglishSkillTracker(storage);

  final GameStorage storage;
  final GameSettings settings;
  final GameAudio audio;

  /// Records answers to skill-tagged questions for the signed-in learner.
  final SkillAnswerSink? skillSink;
  final Random Function() randomFactory;
  final MathSkillTracker mathSkills;
  final EnglishSkillTracker englishSkills;

  late final GameStoryProgress story = GameStoryProgress(storage);

  final Map<QuizGameKind, GameScoreStore> _scores = {};

  /// Drives one round through the story chapters in [theme].
  GameStoryDriver storyDriver(GameVisualTheme theme) =>
      GameStoryDriver(audio: audio, theme: theme, progress: story);

  GameScoreStore scoresFor(QuizGameKind game) =>
      _scores.putIfAbsent(game, () => GameScoreStore(storage, gameId: game.id));

  Future<QuizLevel> level(QuizGameKind game) async =>
      game.subject.levelFromId(await storage.read('games.${game.id}.level'));

  Future<void> saveLevel(QuizGameKind game, QuizLevel level) =>
      storage.write('games.${game.id}.level', level.id);

  Future<GameVisualTheme> theme(QuizGameKind game) async =>
      GameVisualTheme.fromName(await storage.read('games.${game.id}.theme'));

  Future<void> saveTheme(QuizGameKind game, GameVisualTheme theme) =>
      storage.write('games.${game.id}.theme', theme.name);

  SkillTracker trackerFor(QuizLevel level) {
    if (level is EnglishLevel) return englishSkills;
    return mathSkills;
  }

  /// A math generator wired to the fact tracker so missed facts come back.
  MathProblemGenerator generator(MathLevel level) => MathProblemGenerator(
        level: level,
        random: randomFactory(),
        weakFacts: mathSkills,
      );

  MathRoundLog mathRoundLog(MathLevel level) => MathRoundLog(
      level: level,
      generator: generator(level),
      skills: mathSkills,
      skillSink: skillSink);

  EnglishRoundLog englishRoundLog(EnglishLevel level) => EnglishRoundLog(
        level: level,
        generator: EnglishSource(
            level: level, random: randomFactory(), weakItems: englishSkills),
        skills: englishSkills,
        skillSink: skillSink,
      );

  /// A scored round for any subject's [level].
  QuizRoundLog roundLog(QuizLevel level) {
    if (level is MathLevel) return mathRoundLog(level);
    if (level is EnglishLevel) return englishRoundLog(level);
    throw ArgumentError.value(level, 'level', 'unknown subject');
  }
}
