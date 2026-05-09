import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../session/learning_session_controller.dart';
import 'logs_screen.dart';
import 'vocabulary_card.dart';

const Map<String, String> kLearningLanguageLabels = {
  'en': 'English',
  'zh': 'Chinese',
  'vi': 'Vietnamese',
};

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
        bottom: controller.isAuthInProgress
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: AuthProgressIndicator(isVisible: true),
              )
            : null,
        actions: [
          ProficiencyLevelLabel(
            scale: controller.proficiency.scale,
            level: controller.proficiency.level,
          ),
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
        onSwipeRightToLeft: controller.onSwipeRightToLeft,
        onSwipeLeftToRight: controller.onSwipeLeftToRight,
        onSwipeBottomToTop: controller.onSwipeBottomToTop,
        onSwipeTopToBottom: controller.onSwipeTopToBottom,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LearningLanguageSelector(
                currentLanguage: controller.activeLearningLanguage,
                supportedLanguages: controller.supportedLearningLanguages,
                isLoading: controller.isLoading,
                onChanged: controller.setActiveLearningLanguage,
              ),
            ),
            const SizedBox(height: 16),
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
              child: Text(
                'Swipe Right->Left: next card (15% new, 85% review). '
                'Swipe Left->Right: review-first flow.\n'
                'Swipe Bottom->Top: remembered (10% relearn). '
                'Swipe Top->Bottom: difficult (relearn group).',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.language),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learning language',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _labelFor(currentLanguage),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: isLoading ? null : () => _showPicker(context),
              icon: const Icon(Icons.swap_vert),
              label: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }
}

class LearningCardGestureSurface extends StatefulWidget {
  const LearningCardGestureSurface({
    required this.onSwipeRightToLeft,
    required this.onSwipeLeftToRight,
    required this.onSwipeBottomToTop,
    required this.onSwipeTopToBottom,
    required this.child,
    this.isEnabled = true,
    super.key,
  });

  final bool isEnabled;
  final Future<void> Function() onSwipeRightToLeft;
  final Future<void> Function() onSwipeLeftToRight;
  final Future<void> Function() onSwipeBottomToTop;
  final Future<void> Function() onSwipeTopToBottom;
  final Widget child;

  @override
  State<LearningCardGestureSurface> createState() =>
      _LearningCardGestureSurfaceState();
}

class _LearningCardGestureSurfaceState
    extends State<LearningCardGestureSurface> {
  Offset _panDelta = Offset.zero;
  bool _gestureInFlight = false;

  void _dispatchGesture(Future<void> Function() callback) {
    if (_gestureInFlight) {
      return;
    }
    _gestureInFlight = true;
    unawaited(() async {
      try {
        await callback();
      } catch (_) {
        // Gesture failures must not leave the surface permanently disabled.
      } finally {
        _gestureInFlight = false;
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _panDelta = Offset.zero,
      onPanUpdate: (details) {
        _panDelta += details.delta;
      },
      onPanEnd: (details) {
        if (!widget.isEnabled || _gestureInFlight) {
          _panDelta = Offset.zero;
          return;
        }
        final dx = _panDelta.dx;
        final dy = _panDelta.dy;
        final vel = details.velocity.pixelsPerSecond;
        _panDelta = Offset.zero;
        // Determine primary axis from whichever had more movement.
        if (dx.abs() >= dy.abs()) {
          if (vel.dx < -200 || dx < -80) {
            _dispatchGesture(widget.onSwipeRightToLeft);
          } else if (vel.dx > 200 || dx > 80) {
            _dispatchGesture(widget.onSwipeLeftToRight);
          }
        } else {
          if (vel.dy < -200 || dy < -80) {
            _dispatchGesture(widget.onSwipeBottomToTop);
          } else if (vel.dy > 200 || dy > 80) {
            _dispatchGesture(widget.onSwipeTopToBottom);
          }
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
    final subtitle =
        identifier == null || identifier == title ? null : identifier;
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Text(
          'Level $formattedLevel',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
