import 'package:flutter/material.dart';

import '../models/study_event.dart';
import '../models/user_session.dart';
import '../session/learning_session_controller.dart';
import 'logs_screen.dart';
import 'vocabulary_card.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({required this.controller, super.key});

  final LearningSessionController controller;

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary'),
        bottom: controller.isAuthInProgress
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: AuthProgressIndicator(isVisible: true),
              )
            : null,
        actions: [
          ProficiencyLevelLabel(level: controller.proficiency.level),
        ],
      ),
      drawer: LearningDrawer(
        isSignedIn: controller.userSession != null,
        userSession: controller.userSession,
        isAuthInProgress: controller.isAuthInProgress,
        onVocabulary: () => Navigator.of(context).maybePop(),
        onLogs: () {
          Navigator.of(context).maybePop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LogsScreen(repository: controller.repository),
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
      body: LearningCardGestureSurface(
        isEnabled: !controller.isLoading,
        onNewWordSwipe: controller.showNewWord,
        onRecentReviewSwipe: controller.showRecentReview,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 24),
            if (controller.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (controller.currentWord != null)
              VocabularyCardView(word: controller.currentWord!)
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(controller.statusMessage ?? 'No card loaded.'),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: LearningActionBar(
                isLoading: controller.isLoading,
                onNewWord: controller.showNewWord,
                onReview: controller.showRecentReview,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: RatingButtonBar(
                onEasy: controller.currentWord == null || controller.isLoading
                    ? null
                    : () => controller.rateCurrent(StudyRating.easy),
                onTooEasy: controller.currentWord == null || controller.isLoading
                    ? null
                    : () => controller.rateCurrent(StudyRating.tooEasy),
                onHard: controller.currentWord == null || controller.isLoading
                    ? null
                    : () => controller.rateCurrent(StudyRating.hard),
                onTooHard: controller.currentWord == null || controller.isLoading
                    ? null
                    : () => controller.rateCurrent(StudyRating.tooHard),
              ),
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
}

class LearningCardGestureSurface extends StatefulWidget {
  const LearningCardGestureSurface({
    required this.onNewWordSwipe,
    required this.onRecentReviewSwipe,
    required this.child,
    this.isEnabled = true,
    super.key,
  });

  final bool isEnabled;
  final Future<void> Function() onNewWordSwipe;
  final Future<void> Function() onRecentReviewSwipe;
  final Widget child;

  @override
  State<LearningCardGestureSurface> createState() => _LearningCardGestureSurfaceState();
}

class _LearningCardGestureSurfaceState extends State<LearningCardGestureSurface> {
  double _horizontalDragDelta = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _horizontalDragDelta = 0,
      onHorizontalDragUpdate: (details) {
        _horizontalDragDelta += details.primaryDelta ?? 0;
      },
      onHorizontalDragEnd: (details) {
        if (!widget.isEnabled) {
          _horizontalDragDelta = 0;
          return;
        }
        final velocity = details.primaryVelocity ?? 0;
        final delta = _horizontalDragDelta;
        _horizontalDragDelta = 0;
        // Product semantics: right-to-left requests a new word; left-to-right requests review.
        if (velocity < -200 || delta < -80) {
          widget.onNewWordSwipe();
        } else if (velocity > 200 || delta > 80) {
          widget.onRecentReviewSwipe();
        }
      },
      child: widget.child,
    );
  }
}

class LearningDrawer extends StatelessWidget {
  const LearningDrawer({
    required this.isSignedIn,
    required this.onVocabulary,
    required this.onLogs,
    required this.onRegister,
    required this.onSignIn,
    required this.onSignOut,
    this.userSession,
    this.isAuthInProgress = false,
    super.key,
  });

  final bool isSignedIn;
  final UserSession? userSession;
  final bool isAuthInProgress;
  final VoidCallback onVocabulary;
  final VoidCallback onLogs;
  final VoidCallback onRegister;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Vocabulary'),
              onTap: onVocabulary,
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Logs'),
              onTap: onLogs,
            ),
            if (isSignedIn)
              _DrawerUserInfo(
                userSession: userSession,
              ),
            const Spacer(),
            if (isSignedIn)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: isAuthInProgress ? null : onSignOut,
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Register'),
                onTap: isAuthInProgress ? null : onRegister,
              ),
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign in'),
                onTap: isAuthInProgress ? null : onSignIn,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DrawerUserInfo extends StatelessWidget {
  const _DrawerUserInfo({required this.userSession});

  final UserSession? userSession;

  @override
  Widget build(BuildContext context) {
    final displayName = userSession?.displayName?.trim();
    final identifier = userSession?.identifier;
    final title = displayName == null || displayName.isEmpty
        ? identifier ?? 'Signed in'
        : displayName;
    final subtitle = identifier == null || identifier == title ? null : identifier;
    return ListTile(
      leading: const Icon(Icons.account_circle_outlined),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
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
    final passwordError = password.length < 8
        ? 'Password must be at least 8 characters.'
        : null;

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
  const ProficiencyLevelLabel({required this.level, super.key});

  final String level;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Text(
          'Level $level',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class LearningActionBar extends StatelessWidget {
  const LearningActionBar({
    required this.isLoading,
    required this.onNewWord,
    required this.onReview,
    super.key,
  });

  final bool isLoading;
  final Future<void> Function() onNewWord;
  final Future<void> Function() onReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Swipe left for a new word. Swipe right for review.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : () => onNewWord(),
                icon: const Icon(Icons.chevron_left),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('New Word'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : () => onReview(),
                icon: const Icon(Icons.chevron_right),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Review'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class RatingButtonBar extends StatelessWidget {
  const RatingButtonBar({
    required this.onEasy,
    required this.onTooEasy,
    required this.onHard,
    required this.onTooHard,
    super.key,
  });

  final VoidCallback? onEasy;
  final VoidCallback? onTooEasy;
  final VoidCallback? onHard;
  final VoidCallback? onTooHard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RatingButton(
            label: 'Easy',
            onPressed: onEasy,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RatingButton(
            label: 'Too Easy',
            onPressed: onTooEasy,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RatingButton(
            label: 'Hard',
            onPressed: onHard,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RatingButton(
            label: 'Too Hard',
            onPressed: onTooHard,
          ),
        ),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: 56,
        child: FilledButton(
          onPressed: onPressed,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1),
          ),
        ),
      ),
    );
  }
}
