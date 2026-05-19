import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../models/submitted_word.dart';

class SubmittedWordsScreen extends StatefulWidget {
  const SubmittedWordsScreen({
    required this.repository,
    required this.initialLanguage,
    required this.supportedLanguages,
    super.key,
  });

  final WordRepository repository;
  final String initialLanguage;
  final List<String> supportedLanguages;

  @override
  State<SubmittedWordsScreen> createState() => _SubmittedWordsScreenState();
}

class _SubmittedWordsScreenState extends State<SubmittedWordsScreen> {
  final TextEditingController _termController = TextEditingController();
  late String _selectedLanguage;
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<SubmittedWord> _items = const [];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.supportedLanguages.contains(widget.initialLanguage)
        ? widget.initialLanguage
        : widget.supportedLanguages.first;
    _refresh();
  }

  @override
  void dispose() {
    _termController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
    });
    final items = await widget.repository.refreshSubmittedWords();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _submit() async {
    final rawTerm = _termController.text.trim();
    if (rawTerm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a word or short expression.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    final submission = await widget.repository.submitSubmittedWord(
      term: rawTerm,
      language: _selectedLanguage,
    );
    final items = await widget.repository.loadSubmittedWords();
    if (!mounted) {
      return;
    }
    _termController.clear();
    setState(() {
      _items = items;
      _isSubmitting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_feedbackMessageFor(submission))),
    );
  }

  String _feedbackMessageFor(SubmittedWord submission) {
    return switch (submission.status) {
      SubmittedWordStatus.queuedSync =>
        'Saved locally. The app will upload this word when it can connect.',
      SubmittedWordStatus.queued => 'Word saved and queued for AI processing.',
      SubmittedWordStatus.processing => 'Word saved. AI is preparing it now.',
      SubmittedWordStatus.ready => submission.resolutionType ==
              SubmittedWordResolutionType.existingWord
          ? 'This word already exists and is ready to study.'
          : 'Word is ready and has been added to your study list.',
      SubmittedWordStatus.failed => submission.failureReason ??
          'The app could not prepare this word yet. Try again later.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add word'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Capture a word to study later',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'If you find an unfamiliar word while reading, type it here. '
                      'The app saves it, the backend enriches it with AI, and then it joins your normal study flow.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _termController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _isSubmitting ? null : _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Word or short expression',
                        hintText: 'Example: reliable',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedLanguage,
                      decoration: const InputDecoration(labelText: 'Language'),
                      items: widget.supportedLanguages
                          .map(
                            (language) => DropdownMenuItem<String>(
                              value: language,
                              child: Text(_labelFor(language)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedLanguage = value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(_isSubmitting ? 'Saving...' : 'Save word'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Captured words',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No words captured yet.'),
                ),
              )
            else
              ..._items.map(_buildSubmissionCard),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(SubmittedWord submission) {
    final subtitle = <String>[
      _labelFor(submission.targetLanguage),
      _statusLabel(submission),
      if (submission.failureReason != null && submission.failureReason!.isNotEmpty)
        submission.failureReason!,
      if (submission.status == SubmittedWordStatus.ready &&
          submission.resolvedWord?.meaningVi != null)
        submission.resolvedWord!.meaningVi,
    ].join(' • ');

    return Card(
      child: ListTile(
        leading: Icon(_statusIcon(submission.status)),
        title: Text(submission.submittedTerm),
        subtitle: Text(subtitle),
      ),
    );
  }

  String _labelFor(String language) {
    return switch (language) {
      'en' => 'English',
      'zh' => 'Chinese',
      'vi' => 'Vietnamese',
      _ => language.toUpperCase(),
    };
  }

  String _statusLabel(SubmittedWord submission) {
    return switch (submission.status) {
      SubmittedWordStatus.queuedSync => 'Saved locally',
      SubmittedWordStatus.queued => 'Queued',
      SubmittedWordStatus.processing => 'Processing',
      SubmittedWordStatus.ready => submission.resolutionType ==
              SubmittedWordResolutionType.existingWord
          ? 'Ready (already existed)'
          : 'Ready to study',
      SubmittedWordStatus.failed => 'Failed',
    };
  }

  IconData _statusIcon(SubmittedWordStatus status) {
    return switch (status) {
      SubmittedWordStatus.queuedSync => Icons.cloud_off_outlined,
      SubmittedWordStatus.queued => Icons.schedule_outlined,
      SubmittedWordStatus.processing => Icons.auto_awesome_outlined,
      SubmittedWordStatus.ready => Icons.check_circle_outline,
      SubmittedWordStatus.failed => Icons.error_outline,
    };
  }
}
