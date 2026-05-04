import 'package:flutter/material.dart';

import '../models/study_event.dart';
import '../session/learning_session_controller.dart';
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
    final message = widget.controller.takeLevelChangeMessage();
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary'),
        actions: [
          ProficiencyLevelLabel(level: controller.proficiency.level),
        ],
      ),
      drawer: LearningDrawer(
        isSignedIn: controller.userSession != null,
        onVocabulary: () => Navigator.of(context).maybePop(),
        onRegister: _register,
        onSignIn: _signIn,
        onSignOut: () async {
          Navigator.of(context).maybePop();
          await controller.signOut();
        },
      ),
      body: LearningCardGestureSurface(
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
              child: RatingButtonBar(
                onEasy: () => controller.rateCurrent(StudyRating.easy),
                onTooEasy: () => controller.rateCurrent(StudyRating.tooEasy),
                onHard: () => controller.rateCurrent(StudyRating.hard),
                onTooHard: () => controller.rateCurrent(StudyRating.tooHard),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _register() async {
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

class LearningCardGestureSurface extends StatelessWidget {
  const LearningCardGestureSurface({
    required this.onNewWordSwipe,
    required this.onRecentReviewSwipe,
    required this.child,
    super.key,
  });

  final Future<void> Function() onNewWordSwipe;
  final Future<void> Function() onRecentReviewSwipe;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -200) {
          onNewWordSwipe();
        } else if (velocity > 200) {
          onRecentReviewSwipe();
        }
      },
      child: child,
    );
  }
}

class LearningDrawer extends StatelessWidget {
  const LearningDrawer({
    required this.isSignedIn,
    required this.onVocabulary,
    required this.onRegister,
    required this.onSignIn,
    required this.onSignOut,
    super.key,
  });

  final bool isSignedIn;
  final VoidCallback onVocabulary;
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
            const Spacer(),
            if (isSignedIn)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: onSignOut,
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Register'),
                onTap: onRegister,
              ),
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign in'),
                onTap: onSignIn,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IdentityCredentials {
  const _IdentityCredentials({
    required this.identifier,
    required this.password,
    this.displayName,
  });

  final String identifier;
  final String password;
  final String? displayName;
}

Future<_IdentityCredentials?> _showIdentityDialog({
  required BuildContext context,
  required String title,
  bool includeDisplayName = false,
}) {
  final identifierController = TextEditingController();
  final passwordController = TextEditingController();
  final displayNameController = TextEditingController();
  return showDialog<_IdentityCredentials>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: identifierController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
            ),
            if (includeDisplayName)
              TextField(
                controller: displayNameController,
                decoration: const InputDecoration(labelText: 'Name'),
                autofillHints: const [AutofillHints.name],
              ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
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
            onPressed: () {
              Navigator.of(context).pop(
                _IdentityCredentials(
                  identifier: identifierController.text.trim(),
                  password: passwordController.text,
                  displayName: displayNameController.text.trim().isEmpty
                      ? null
                      : displayNameController.text.trim(),
                ),
              );
            },
            child: Text(title),
          ),
        ],
      );
    },
  ).whenComplete(() {
    identifierController.dispose();
    passwordController.dispose();
    displayNameController.dispose();
  });
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

class RatingButtonBar extends StatelessWidget {
  const RatingButtonBar({
    required this.onEasy,
    required this.onTooEasy,
    required this.onHard,
    required this.onTooHard,
    super.key,
  });

  final VoidCallback onEasy;
  final VoidCallback onTooEasy;
  final VoidCallback onHard;
  final VoidCallback onTooHard;

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
  final VoidCallback onPressed;

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
