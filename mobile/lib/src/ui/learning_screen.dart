import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../config.dart';
import '../games/common/game_audio.dart';
import '../games/common/game_settings.dart';
import '../games/word_blaster/word_blaster_context.dart';
import '../games/game_storage.dart';
import '../games/games_hub_screen.dart';
import '../data/article_repository.dart';
import '../data/memorization_repository.dart';
import '../data/workplace_sentence_repository.dart';
import '../data/word_repository.dart';
import '../exam/exam_session_controller.dart';
import '../exam/exam_question_screen.dart';
import '../models/user_session.dart';
import '../session/learning_session_controller.dart';
import '../session/workplace_sentence_session_controller.dart';
import '../speaking/speaking_drill_screen.dart';
import '../speaking/speaking_repository.dart';
import '../speaking/speaking_summary_screen.dart';
import '../data/shadowing_repository.dart';
import '../shadowing/shadowing_library_screen.dart';
import 'articles_screen.dart';
import 'memorization_screen.dart';
import 'learning_gesture_surface.dart';
import 'fitb_card.dart';
import 'logs_screen.dart';
import 'submitted_words_screen.dart';
import 'upgrade_check_screen.dart';
import 'vocabulary_card.dart';
import 'workplace_sentence_screen.dart';
import 'learning_history_screen.dart';
import 'learning_progress_stats_screen.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/study_action_bar.dart';

const Map<String, String> kLearningLanguageLabels = {
  'en': 'English',
  'zh': 'Chinese',
  'vi': 'Vietnamese',
};

class LearningScreen extends StatefulWidget {
  const LearningScreen({
    required this.controller,
    required this.articleRepository,
    required this.memorizationRepository,
    required this.workplaceSentenceRepository,
    this.speakingRepository,
    this.shadowingRepository,
    super.key,
  });

  final LearningSessionController controller;
  final ArticleRepository articleRepository;
  final MemorizationRepository memorizationRepository;
  final WorkplaceSentenceRepository workplaceSentenceRepository;
  final SpeakingRepository? speakingRepository;
  final ShadowingRepository? shadowingRepository;

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.loadInitial();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
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
        title: const Text('Vocabulary'),
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
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: LearningCardGestureSurface(
                isEnabled: !controller.isLoading,
                onSwipeRightToLeft: controller.onSwipeRightToLeft,
                onSwipeLeftToRight: _handleHistoryGesture,
                onSwipeBottomToTop: controller.onSwipeBottomToTop,
                onSwipeTopToBottom: controller.onSwipeTopToBottom,
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (controller.isLoading)
                            const Padding(
                              padding: EdgeInsets.only(top: 120),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (controller.currentWord != null)
                            controller.shouldShowFitb(
                              controller.currentWord!,
                              cardKind: controller.currentCardKind,
                            )
                                ? FitbCard(word: controller.currentWord!)
                                : VocabularyCardView(
                                    word: controller.currentWord!,
                                    speakingRepository:
                                        widget.speakingRepository,
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
            StudyActionBar(
              enabled: !controller.isLoading && controller.currentWord != null,
              onDifficult: controller.onSwipeTopToBottom,
              onNext: controller.onSwipeRightToLeft,
              onRemembered: controller.onSwipeBottomToTop,
              swipeHint:
                  'You can also swipe the card: left for next, up if you remember it, down if it is hard.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (widget.controller.isAuthInProgress) {
      return;
    }
    Navigator.of(context).maybePop();
    final credentials = await _showIdentityDialog(
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
    final credentials = await _showIdentityDialog(
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
    final speaking = widget.speakingRepository;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamesHubScreen(
          storage: storage,
          wordBlaster: AppConfig.fromEnvironment().wordBlasterEnabled
              ? WordBlasterContext(
                  repository: repository,
                  storage: storage,
                  settings: settings,
                  audio: GameAudio(settings),
                  language: controller.activeLearningLanguage,
                  learnerLevelIndex: controller.proficiency.levelIndex,
                  speak: speaking == null
                      ? null
                      : (text, languageCode) =>
                          speaking.playSample(text, languageCode: languageCode),
                  logger: repository.logger,
                  onRoundFinished: (round) =>
                      repository.enqueueGameRound(round.toSyncJson()),
                  fetchLeaderboard: repository.fetchGameLeaderboard,
                )
              : null,
        ),
      ),
    );
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

class LearningLanguageSelector extends StatelessWidget {
  const LearningLanguageSelector({
    required this.currentLanguage,
    required this.supportedLanguages,
    required this.isLoading,
    required this.onChanged,
    super.key,
  });

  final String currentLanguage;
  final List<String> supportedLanguages;
  final bool isLoading;
  final Future<void> Function(String language) onChanged;

  String _labelFor(String language) {
    return kLearningLanguageLabels[language] ?? language.toUpperCase();
  }

  Future<void> _showPicker(BuildContext context) async {
    if (isLoading) {
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                'Choose learning language',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final language in supportedLanguages)
                ListTile(
                  title: Text(_labelFor(language)),
                  subtitle: Text(language.toUpperCase()),
                  trailing: language == currentLanguage
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: () => Navigator.of(context).pop(language),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null && selected != currentLanguage) {
      await onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _labelFor(currentLanguage);
    return Tooltip(
      message: 'Change learning language',
      child: Semantics(
        button: true,
        label: 'Learning language: $label. Change',
        excludeSemantics: true,
        child: ActionChip(
          avatar: const Icon(Icons.translate_rounded, size: 18),
          label: Text(label),
          onPressed: isLoading ? null : () => _showPicker(context),
          labelStyle: theme.textTheme.labelLarge,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class LearningDrawer extends StatelessWidget {
  const LearningDrawer({
    required this.isSignedIn,
    required this.onVocabulary,
    required this.onWorkplaceSentences,
    required this.onLogs,
    required this.onArticles,
    required this.onMemorization,
    required this.onSubmittedWords,
    required this.onHistory,
    required this.onStats,
    required this.onRegister,
    required this.onSignIn,
    required this.onSignOut,
    this.speakingRepository,
    this.wordRepository,
    this.userSession,
    this.isAuthInProgress = false,
    this.onExam,
    this.onShadowing,
    this.onCheckUpdates,
    this.onGames,
    super.key,
  });

  final bool isSignedIn;
  final UserSession? userSession;
  final bool isAuthInProgress;
  final SpeakingRepository? speakingRepository;
  final WordRepository? wordRepository; // for speaking stats fetch
  final VoidCallback onVocabulary;
  final VoidCallback onWorkplaceSentences;
  final VoidCallback onLogs;
  final VoidCallback onArticles;
  final VoidCallback onMemorization;
  final VoidCallback onSubmittedWords;
  final VoidCallback onHistory;
  final VoidCallback onStats;
  final VoidCallback onRegister;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  /// Called when the user taps "Take Exam". Only shown when signed in.
  final VoidCallback? onExam;

  /// Called when the user taps "Video Shadowing".
  final VoidCallback? onShadowing;

  /// Called when the user taps "Check for updates".
  final VoidCallback? onCheckUpdates;

  /// Called when the user taps "Games". Games run fully offline.
  final VoidCallback? onGames;

  void _go(BuildContext context, VoidCallback action) {
    Navigator.of(context).maybePop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final speaking = speakingRepository;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                children: [
                  _DrawerHeaderCard(
                    isSignedIn: isSignedIn,
                    userSession: userSession,
                    isAuthInProgress: isAuthInProgress,
                    onSignIn: onSignIn,
                    onRegister: onRegister,
                  ),
                  const _DrawerSection('Learn'),
                  _DrawerItem(
                    icon: Icons.menu_book_rounded,
                    label: 'Vocabulary',
                    selected: true,
                    onTap: onVocabulary,
                  ),
                  _DrawerItem(
                    icon: Icons.record_voice_over_outlined,
                    label: 'Sentences',
                    onTap: onWorkplaceSentences,
                  ),
                  _DrawerItem(
                    icon: Icons.add_circle_outline,
                    label: 'Add word',
                    onTap: onSubmittedWords,
                  ),
                  if (isSignedIn)
                    _DrawerItem(
                      icon: Icons.auto_stories_outlined,
                      label: 'Memorization',
                      onTap: onMemorization,
                    ),
                  if (isSignedIn)
                    _DrawerItem(
                      icon: Icons.article_outlined,
                      label: 'Articles',
                      onTap: onArticles,
                    ),
                  const _DrawerSection('Practice'),
                  if (speaking != null)
                    _DrawerItem(
                      icon: Icons.mic_none_rounded,
                      label: '3-minute drill',
                      onTap: () => _go(
                        context,
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                SpeakingDrillScreen(repository: speaking),
                          ),
                        ),
                      ),
                    ),
                  if (onShadowing != null)
                    _DrawerItem(
                      icon: Icons.play_circle_outline,
                      label: 'Video Shadowing',
                      onTap: onShadowing!,
                    ),
                  if (onGames != null)
                    _DrawerItem(
                      icon: Icons.sports_esports_outlined,
                      label: 'Games',
                      onTap: () => _go(context, onGames!),
                    ),
                  if (isSignedIn && onExam != null)
                    _DrawerItem(
                      icon: Icons.quiz_outlined,
                      label: 'Take Exam',
                      onTap: () => _go(context, onExam!),
                    ),
                  const _DrawerSection('Progress'),
                  _DrawerItem(
                    icon: Icons.history_rounded,
                    label: 'History',
                    onTap: onHistory,
                  ),
                  _DrawerItem(
                    icon: Icons.insights_rounded,
                    label: 'Stats',
                    onTap: onStats,
                  ),
                  if (speaking != null)
                    _DrawerItem(
                      icon: Icons.graphic_eq_rounded,
                      label: 'Speaking stats',
                      onTap: () => _go(
                        context,
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                SpeakingSummaryScreen(repository: speaking),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: const ValueKey('drawer-tools'),
                      leading: const Icon(Icons.tune_rounded),
                      title: const Text('Tools & settings'),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      childrenPadding: const EdgeInsets.only(left: 8),
                      children: [
                        if (onCheckUpdates != null)
                          _DrawerItem(
                            icon: Icons.system_update_outlined,
                            label: 'Check for updates',
                            onTap: onCheckUpdates!,
                          ),
                        _DrawerItem(
                          icon: Icons.bug_report_outlined,
                          label: 'Logs',
                          onTap: onLogs,
                        ),
                        if (speaking != null)
                          _DrawerItem(
                            icon: Icons.delete_outline,
                            label: 'Delete all recordings',
                            onTap: () async {
                              Navigator.of(context).maybePop();
                              await _confirmDeleteAll(context);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isSignedIn)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _DrawerItem(
                  icon: Icons.logout_rounded,
                  label: 'Sign out',
                  onTap: isAuthInProgress ? null : onSignOut,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all recordings?'),
        content: const Text(
          'This removes all speaking audio files and attempt records from this device. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await speakingRepository!.deleteAllRecordings();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All recordings deleted.')),
        );
      }
    }
  }
}

class _DrawerHeaderCard extends StatelessWidget {
  const _DrawerHeaderCard({
    required this.isSignedIn,
    required this.userSession,
    required this.isAuthInProgress,
    required this.onSignIn,
    required this.onRegister,
  });

  final bool isSignedIn;
  final UserSession? userSession;
  final bool isAuthInProgress;
  final VoidCallback onSignIn;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayName = userSession?.displayName?.trim();
    final identifier = userSession?.identifier;
    final title = !isSignedIn
        ? 'Guest'
        : (displayName == null || displayName.isEmpty
            ? identifier ?? 'Signed in'
            : displayName);
    final subtitle = !isSignedIn
        ? 'Sign in to keep your progress on every device.'
        : (identifier == null || identifier == title ? null : identifier);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                child: isSignedIn && title.isNotEmpty
                    ? Text(
                        title.characters.first.toUpperCase(),
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: scheme.onPrimary),
                      )
                    : const Icon(Icons.person_outline_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!isSignedIn) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: isAuthInProgress ? null : onSignIn,
                    child: const Text('Sign in'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isAuthInProgress ? null : onRegister,
                    child: const Text('Register'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      selectedColor: scheme.onSecondaryContainer,
      selectedTileColor: scheme.secondaryContainer,
      visualDensity: VisualDensity.compact,
      onTap: onTap,
    );
  }
}

class IdentityCredentials {
  const IdentityCredentials({
    required this.identifier,
    required this.password,
    this.displayName,
  });

  final String identifier;
  final String password;
  final String? displayName;
}

Future<IdentityCredentials?> _showIdentityDialog({
  required BuildContext context,
  required String title,
  bool includeDisplayName = false,
}) {
  return showDialog<IdentityCredentials>(
    context: context,
    builder: (context) {
      return IdentityDialog(
        title: title,
        includeDisplayName: includeDisplayName,
        onSubmit: (credentials) => Navigator.of(context).pop(credentials),
      );
    },
  );
}

class IdentityDialog extends StatefulWidget {
  const IdentityDialog({
    required this.title,
    required this.onSubmit,
    this.includeDisplayName = false,
    super.key,
  });

  final String title;
  final bool includeDisplayName;
  final ValueChanged<IdentityCredentials> onSubmit;

  @override
  State<IdentityDialog> createState() => _IdentityDialogState();
}

class _IdentityDialogState extends State<IdentityDialog> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  String? _identifierError;
  String? _passwordError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _identifierController,
            decoration: InputDecoration(
              labelText: 'Email',
              errorText: _identifierError,
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username],
          ),
          if (widget.includeDisplayName)
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: 'Name'),
              autofillHints: const [AutofillHints.name],
            ),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              errorText: _passwordError,
            ),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.title),
        ),
      ],
    );
  }

  void _submit() {
    final identifier = _identifierController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final identifierError = _validateIdentifier(identifier);
    final passwordError =
        password.length < 8 ? 'Password must be at least 8 characters.' : null;

    setState(() {
      _identifierError = identifierError;
      _passwordError = passwordError;
    });

    if (identifierError != null || passwordError != null) {
      return;
    }

    final displayName = _displayNameController.text.trim();
    widget.onSubmit(
      IdentityCredentials(
        identifier: identifier,
        password: password,
        displayName: displayName.isEmpty ? null : displayName,
      ),
    );
  }

  String? _validateIdentifier(String identifier) {
    if (identifier.isEmpty) {
      return 'Enter an email address.';
    }
    final emailLikePattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailLikePattern.hasMatch(identifier)) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}

class AuthProgressIndicator extends StatelessWidget {
  const AuthProgressIndicator({required this.isVisible, super.key});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }
    return const LinearProgressIndicator(minHeight: 4);
  }
}

class ProficiencyLevelLabel extends StatelessWidget {
  const ProficiencyLevelLabel({
    required this.scale,
    required this.level,
    super.key,
  });

  final String scale;
  final String level;

  String get formattedLevel {
    if (scale.toLowerCase() == 'hsk') {
      return level.toUpperCase().startsWith('HSK')
          ? level.toUpperCase()
          : 'HSK$level';
    }
    return level.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Level $formattedLevel',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
