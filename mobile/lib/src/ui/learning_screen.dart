import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../config.dart';
import '../games/common/game_audio.dart';
import '../games/common/game_settings.dart';
import '../games/word_blaster/word_blaster_context.dart';
import '../games/game_storage.dart';
import '../games/games_hub_screen.dart';
import '../games/party/party_relay_host.dart';
import '../games/quiz/quiz_game_context.dart';
import '../curriculum/local_skill_answer_sink.dart';
import '../data/article_repository.dart';
import '../data/memorization_repository.dart';
import '../data/workplace_sentence_repository.dart';
import '../engagement/engagement_controller.dart';
import '../engagement/engagement_panel.dart';
import '../engagement/engagement_repository.dart';
import '../engagement/engagement_settings_sheet.dart';
import '../exam/exam_session_controller.dart';
import '../exam/exam_question_screen.dart';
import '../session/learning_session_controller.dart';
import '../session/workplace_sentence_session_controller.dart';
import '../speaking/speaking_repository.dart';
import '../data/shadowing_repository.dart';
import '../shadowing/shadowing_library_screen.dart';
import 'articles_screen.dart';
import 'memorization_screen.dart';
import 'learning_gesture_surface.dart';
import 'review_exercise_view.dart';
import 'logs_screen.dart';
import 'submitted_words_screen.dart';
import 'upgrade_check_screen.dart';
import 'vocabulary_card.dart';
import 'workplace_sentence_screen.dart';
import 'learning_history_screen.dart';
import 'learning_progress_stats_screen.dart';
import '../widgets/brand_backdrop.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/study_action_bar.dart';
import 'identity_dialog.dart';
import 'learning_drawer.dart';
import 'study_level_widgets.dart';

export 'identity_dialog.dart';
export 'learning_drawer.dart';
export 'study_level_widgets.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({
    required this.controller,
    required this.articleRepository,
    required this.memorizationRepository,
    required this.workplaceSentenceRepository,
    this.speakingRepository,
    this.shadowingRepository,
    this.engagement,
    super.key,
  });

  final LearningSessionController controller;
  final ArticleRepository articleRepository;
  final MemorizationRepository memorizationRepository;
  final WorkplaceSentenceRepository workplaceSentenceRepository;
  final SpeakingRepository? speakingRepository;
  final ShadowingRepository? shadowingRepository;

  /// Streak/goal/reminder state; built from the local database when absent.
  final EngagementController? engagement;

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  late final EngagementController _engagement = widget.engagement ??
      EngagementController(
        repository: EngagementRepository(
            database: widget.controller.repository.database),
      );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _engagement.addListener(_onEngagementChanged);
    widget.controller.loadInitial();
    _refreshEngagement();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _engagement.removeListener(_onEngagementChanged);
    if (widget.engagement == null) _engagement.dispose();
    super.dispose();
  }

  void _onEngagementChanged() => setState(() {});

  // Ratings, sign-in/out and language switches all notify the controller;
  // the engagement controller coalesces the resulting refreshes.
  void _refreshEngagement() =>
      _engagement.refresh(language: widget.controller.activeLearningLanguage);

  void _onControllerChanged() {
    setState(() {});
    _refreshEngagement();
    final messages = [
      widget.controller.takeUserFeedbackMessage(),
      widget.controller.takeLevelChangeMessage(),
    ].whereType<String>();
    for (final message in messages) {
      _showSnackBar(message);
    }
  }

  void _showSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(
        // Scales down instead of overflowing when the action chips take the
        // room (narrow phones, large text).
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_rounded,
                  size: 22, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Vocabulary'),
            ],
          ),
        ),
        titleSpacing: 0,
        actions: [
          LearningLanguageSelector(
            currentLanguage: controller.activeLearningLanguage,
            supportedLanguages: controller.supportedLearningLanguages,
            isLoading: controller.isLoading,
            onChanged: controller.setActiveLearningLanguage,
          ),
          const SizedBox(width: 6),
          ProficiencyLevelLabel(
            scale: controller.proficiency.scale,
            level: controller.proficiency.level,
            studyLevel: controller.isStudyLevelOverridden
                ? controller.studyLevel
                : null,
            onTap: controller.isLoading ? null : _openLevelPicker,
          ),
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded),
            onPressed: _openHistory,
          ),
          const SizedBox(width: 4),
        ],
        bottom: controller.isAuthInProgress
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: AuthProgressIndicator(isVisible: true),
              )
            : null,
      ),
      drawer: LearningDrawer(
        isSignedIn: controller.userSession != null,
        userSession: controller.userSession,
        isAuthInProgress: controller.isAuthInProgress,
        speakingRepository: widget.speakingRepository,
        wordRepository: controller.repository,
        onArticles: _openArticles,
        onMemorization: _openMemorization,
        onSubmittedWords: _openSubmittedWords,
        onVocabulary: () => Navigator.of(context).maybePop(),
        onWorkplaceSentences: _openWorkplaceSentences,
        onGames: _openGames,
        onHistory: _openHistory,
        onStats: _openStats,
        onDailyGoal: _openEngagementSettings,
        onLogs: () {
          Navigator.of(context).maybePop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LogsScreen(repository: controller.repository),
            ),
          );
        },
        onExam: controller.userSession == null ? null : _openExam,
        onShadowing: widget.shadowingRepository != null ? _openShadowing : null,
        onCheckUpdates: () {
          Navigator.of(context).maybePop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UpgradeCheckScreen(
                apiClient: controller.repository.apiClient,
                onInstallApk: (apkPath) async {
                  await OpenFilex.open(apkPath,
                      type: 'application/vnd.android.package-archive');
                },
              ),
            ),
          );
        },
        onRegister: _register,
        onSignIn: _signIn,
        onSignOut: () async {
          Navigator.of(context).maybePop();
          await controller.signOut();
        },
      ),
      body: BrandBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              if (_engagement.snapshot case final snapshot?)
                EngagementPanel(
                  snapshot: snapshot,
                  onOpenSettings: _openEngagementSettings,
                ),
              Expanded(
                child: LearningCardGestureSurface(
                  // A review exercise is graded by its answer; Continue moves on.
                  isEnabled: !controller.isLoading &&
                      controller.currentExercise == null,
                  onSwipeRightToLeft: controller.onSwipeRightToLeft,
                  onSwipeLeftToRight: _handleHistoryGesture,
                  onSwipeBottomToTop: controller.onSwipeBottomToTop,
                  onSwipeTopToBottom: controller.onSwipeTopToBottom,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      // Swipes drive plain cards; an exercise card may be taller than
                      // the area, so it scrolls instead.
                      physics: controller.currentExercise == null
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (controller.isLoading)
                              const Padding(
                                padding: EdgeInsets.only(top: 120),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            else if (controller.currentExercise
                                case final exercise?)
                              ReviewExerciseView(
                                key: ValueKey(
                                    'review-${exercise.word.localId}-${exercise.kind.name}'),
                                exercise: exercise,
                                onAnswered: (answer) => controller.answerReview(
                                  correct: answer.correct,
                                  elapsed: answer.elapsed,
                                  nearMiss: answer.nearMiss,
                                ),
                                onListen: _speak,
                              )
                            else if (controller.currentWord != null)
                              VocabularyCardView(
                                word: controller.currentWord!,
                                speakingRepository: widget.speakingRepository,
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: controller.isLoading ||
                                        controller.statusMessage == null
                                    ? const EmptyStateView(
                                        icon: Icons.school_outlined,
                                        title: 'No card loaded',
                                        body:
                                            'Loading your next vocabulary card...',
                                      )
                                    : EmptyStateView(
                                        icon: Icons.inbox_outlined,
                                        title: 'No card available',
                                        body: controller.statusMessage!,
                                        actionLabel: 'Try again',
                                        onAction: controller.showNewWord,
                                      ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (controller.currentExercise != null)
                _ContinueBar(
                  enabled: controller.exerciseAnswered && !controller.isLoading,
                  onContinue: controller.nextCard,
                )
              else
                StudyActionBar(
                  enabled:
                      !controller.isLoading && controller.currentWord != null,
                  onDifficult: controller.onSwipeTopToBottom,
                  onNext: controller.onSwipeRightToLeft,
                  onRemembered: controller.onSwipeBottomToTop,
                  swipeHint:
                      'You can also swipe the card: left for next, up if you remember it, down if it is hard.',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (widget.controller.isAuthInProgress) {
      return;
    }
    Navigator.of(context).maybePop();
    final credentials = await showIdentityDialog(
      context: context,
      title: 'Register',
      includeDisplayName: true,
    );
    if (credentials == null) {
      return;
    }
    await widget.controller.register(
      identifier: credentials.identifier,
      password: credentials.password,
      displayName: credentials.displayName,
    );
  }

  Future<void> _signIn() async {
    if (widget.controller.isAuthInProgress) {
      return;
    }
    Navigator.of(context).maybePop();
    final credentials = await showIdentityDialog(
      context: context,
      title: 'Sign in',
    );
    if (credentials == null) {
      return;
    }
    await widget.controller.signIn(
      identifier: credentials.identifier,
      password: credentials.password,
    );
  }

  /// Speaks [term] in the active learning language (review "listen" cards).
  Future<void> _speak(String term) async {
    await widget.speakingRepository?.playSample(term,
        languageCode:
            ttsLanguageCode(widget.controller.activeLearningLanguage));
  }

  Future<void> _openArticles() async {
    final session = widget.controller.userSession;
    if (session == null) {
      return;
    }
    Navigator.of(context).maybePop();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleManagementScreen(
          repository: widget.articleRepository,
          sessionToken: session.sessionToken,
          initialLanguage: widget.controller.activeLearningLanguage,
          supportedLanguages: widget.controller.supportedLearningLanguages,
          onAddToReview: widget.controller.repository.addWordForReview,
        ),
      ),
    );
  }

  void _openShadowing() {
    if (widget.shadowingRepository == null) return;
    Navigator.of(context).maybePop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShadowingLibraryScreen(
          repository: widget.shadowingRepository!,
        ),
      ),
    );
  }

  Future<void> _openMemorization() async {
    final session = widget.controller.userSession;
    if (session == null) {
      return;
    }
    Navigator.of(context).maybePop();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemorizationScreen(
          repository: widget.memorizationRepository,
          userSession: session,
        ),
      ),
    );
  }

  Future<void> _openSubmittedWords() async {
    Navigator.of(context).maybePop();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubmittedWordsScreen(
          repository: widget.controller.repository,
          initialLanguage: widget.controller.activeLearningLanguage,
          supportedLanguages: widget.controller.supportedLearningLanguages,
        ),
      ),
    );
  }

  Future<void> _openExam() async {
    final session = widget.controller.userSession;
    if (session == null) {
      return;
    }
    final repository = widget.controller.repository;
    final examController = ExamSessionController(
      apiClient: repository.apiClient,
      database: repository.database,
    );
    await examController.startSession(
      userSession: session,
      language: widget.controller.activeLearningLanguage,
    );
    if (!mounted) {
      return;
    }
    if (examController.state == ExamState.active) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExamQuestionScreen(
            controller: examController,
            userSession: session,
          ),
        ),
      );
    } else if (examController.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(examController.errorMessage!)));
    }
  }

  Future<void> _openWorkplaceSentences() async {
    Navigator.of(context).maybePop();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkplaceSentenceScreen(
          controller: WorkplaceSentenceSessionController(
            repository: widget.workplaceSentenceRepository,
          ),
        ),
      ),
    );
  }

  Future<void> _handleHistoryGesture() async {
    await widget.controller.onSwipeLeftToRight();
    if (!mounted) {
      return;
    }
    await _openHistory();
  }

  void _openGames() {
    final controller = widget.controller;
    final repository = controller.repository;
    final storage = LocalDatabaseGameStorage(repository.database);
    final settings = GameSettings(storage);
    final audio = GameAudio(settings);
    final speaking = widget.speakingRepository;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => GamesHubScreen(
              storage: storage,
              partyRelay: PartyRelay(repository.apiClient.signedSocket),
              quiz: QuizGameContext(
                  storage: storage,
                  settings: settings,
                  audio: audio,
                  skillSink: LocalSkillAnswerSink(repository.database)),
              wordBlaster: AppConfig.fromEnvironment().wordBlasterEnabled
                  ? WordBlasterContext(
                      repository: repository,
                      storage: storage,
                      settings: settings,
                      audio: audio,
                      language: controller.activeLearningLanguage,
                      learnerLevelIndex: controller.proficiency.levelIndex,
                      speak: speaking == null
                          ? null
                          : (text, languageCode) => speaking.playSample(text,
                              languageCode: languageCode),
                      logger: repository.logger,
                      onRoundFinished: (round) =>
                          repository.enqueueGameRound(round.toSyncJson()),
                      fetchLeaderboard: repository.fetchGameLeaderboard,
                    )
                  : null,
            ),
          ),
        )
        .then((_) => audio.dispose());
  }

  Future<void> _openLevelPicker() async {
    final controller = widget.controller;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => StudyLevelSheet(
        scale: controller.proficiency.scale,
        ownLevel: controller.proficiency.level,
        currentLevel: controller.studyLevel,
        options: controller.studyLevelOptions,
      ),
    );
    if (picked != null) {
      await controller.setStudyLevel(picked);
    }
  }

  Future<void> _openHistory() async {
    Navigator.of(context).maybePop();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearningHistoryScreen(
          database: widget.controller.repository.database,
        ),
      ),
    );
  }

  Future<void> _openEngagementSettings() =>
      showEngagementSettingsSheet(context, _engagement);

  Future<void> _openStats() async {
    Navigator.of(context).maybePop();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearningProgressStatsScreen(
          database: widget.controller.repository.database,
        ),
      ),
    );
  }
}

/// The pinned way forward from a review exercise (in the action bar's place),
/// enabled once the question is answered.
class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.enabled, required this.onContinue});

  final bool enabled;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
            top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          key: const ValueKey('review-continue'),
          onPressed: enabled ? onContinue : null,
          child: Text(enabled ? 'Continue' : 'Choose an answer'),
        ),
      ),
    );
  }
}
