import 'package:flutter/material.dart';

import '../data/local_database.dart';
import '../models/user_session.dart';
import 'exam_question_screen.dart';
import 'exam_session_controller.dart';

/// Language selector screen that starts a vocabulary exam.
///
/// The primary exam flow no longer depends on topic selection — the backend
/// generates questions from all studied words for the chosen language.
/// Navigates to [ExamQuestionScreen] on start.
class ExamTopicScreen extends StatefulWidget {
  const ExamTopicScreen({
    required this.controller,
    required this.userSession,
    this.database,
    super.key,
  });

  final ExamSessionController controller;
  final UserSession userSession;

  /// Optional database for persisting the selected exam language.
  final LocalDatabase? database;

  @override
  State<ExamTopicScreen> createState() => _ExamTopicScreenState();
}

class _ExamTopicScreenState extends State<ExamTopicScreen> {
  String _language = 'en';

  static const _settingKey = 'exam_language';

  static const _languages = {
    'en': 'English',
    'zh': 'Chinese',
    'vi': 'Vietnamese',
    'en-idioms': 'English Idioms',
    'zh-idioms': 'Chinese Idioms (成语)',
  };

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final db = widget.database;
    if (db == null) return;
    final saved = await db.getSetting(_settingKey);
    if (saved != null && _languages.containsKey(saved) && mounted) {
      setState(() => _language = saved);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _onLanguageChanged(String? value) async {
    if (value == null || value == _language) return;
    setState(() => _language = value);
    await widget.database?.setSetting(_settingKey, value);
  }

  Future<void> _startExam() async {
    await widget.controller.startSession(
      userSession: widget.userSession,
      language: _language,
    );

    if (!mounted) return;
    if (widget.controller.state == ExamState.active) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExamQuestionScreen(
            controller: widget.controller,
            userSession: widget.userSession,
          ),
        ),
      );
      // Reset after returning so the screen is fresh for the next attempt.
      widget.controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.controller.state == ExamState.loading;
    final errorMessage = widget.controller.errorMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary Exam')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exam description card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How it works',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'Answer up to 20 multiple-choice questions drawn from '
                      'words you have studied. You need at least 5 studied '
                      'words to start. A score of 70% or higher earns a '
                      'certificate.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Language picker
            DropdownButtonFormField<String>(
              value: _language,
              decoration: const InputDecoration(
                labelText: 'Language',
                border: OutlineInputBorder(),
              ),
              items: _languages.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: isLoading ? null : _onLanguageChanged,
            ),

            if (errorMessage != null &&
                widget.controller.state == ExamState.idle) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],

            const Spacer(),

            // Start button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading ? null : _startExam,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start Exam'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
