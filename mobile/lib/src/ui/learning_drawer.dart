import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../models/user_session.dart';
import '../speaking/speaking_drill_screen.dart';
import '../speaking/speaking_repository.dart';
import '../speaking/speaking_summary_screen.dart';

// Navigation drawer of the learning screen.
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
    this.onDailyGoal,
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

  /// Called when the user taps "Daily goal & reminder".
  final VoidCallback? onDailyGoal;

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
                  if (onDailyGoal != null)
                    _DrawerItem(
                      icon: Icons.flag_outlined,
                      label: 'Daily goal & reminder',
                      onTap: () => _go(context, onDailyGoal!),
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
