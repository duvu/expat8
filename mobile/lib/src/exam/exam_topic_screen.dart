import 'package:flutter/material.dart';

import '../api/backend_api_client.dart';
import '../models/user_session.dart';
import 'exam_question_screen.dart';
import 'exam_session_controller.dart';

/// Topic and language selector screen that starts a vocabulary exam.
///
/// Fetches the authenticated user's studied topics for the selected language
/// and lets them pick one. Navigates to [ExamQuestionScreen] on start.
class ExamTopicScreen extends StatefulWidget {
  const ExamTopicScreen({
    required this.controller,
    required this.userSession,
    super.key,
  });

  final ExamSessionController controller;
  final UserSession userSession;

  @override
  State<ExamTopicScreen> createState() => _ExamTopicScreenState();
}

class _ExamTopicScreenState extends State<ExamTopicScreen> {
  String _language = 'en';
  List<String> _topics = [];
  bool _loadingTopics = false;
  String? _selectedTopic;
  String? _errorMessage;

  static const _languages = {
    'en': 'English',
    'zh': 'Chinese',
    'vi': 'Vietnamese',
  };

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _loadTopics();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    final err = widget.controller.errorMessage;
    if (err != null && widget.controller.state == ExamState.idle) {
      _errorMessage = err;
    }
  }

  Future<void> _loadTopics() async {
    setState(() {
      _loadingTopics = true;
      _selectedTopic = null;
      _errorMessage = null;
    });
    final topics = await widget.controller
        .fetchTopics(userSession: widget.userSession, language: _language);
    if (!mounted) return;
    setState(() {
      _topics = topics;
      _loadingTopics = false;
    });
  }

  Future<void> _startExam() async {
    final topic = _selectedTopic;
    if (topic == null) return;

    await widget.controller.startSession(
      userSession: widget.userSession,
      topic: topic,
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
      // Reset after returning so the topic screen is fresh for the next attempt.
      widget.controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _loadingTopics ||
        widget.controller.state == ExamState.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary Exam')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language picker
            Text('Language', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _language,
              isExpanded: true,
              items: _languages.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: isLoading
                  ? null
                  : (value) {
                      if (value != null && value != _language) {
                        setState(() => _language = value);
                        _loadTopics();
                      }
                    },
            ),
            const SizedBox(height: 24),

            // Topic picker
            Text('Topic', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            if (_loadingTopics)
              const Center(child: CircularProgressIndicator())
            else if (_topics.isEmpty)
              Text(
                'No topics available for ${_languages[_language] ?? _language}. '
                'Keep studying to unlock exam topics.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              DropdownButton<String>(
                value: _selectedTopic,
                isExpanded: true,
                hint: const Text('Select a topic'),
                items: _topics
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(_capitalise(t)),
                        ))
                    .toList(),
                onChanged: isLoading
                    ? null
                    : (value) => setState(() => _selectedTopic = value),
              ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
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
                onPressed: (isLoading || _selectedTopic == null)
                    ? null
                    : _startExam,
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

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
