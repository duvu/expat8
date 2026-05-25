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
        'The request did not finish. Please try again when your connection is stable.',
      SubmittedWordStatus.queued => 'This word is still pending from an older app flow.',
      SubmittedWordStatus.processing => 'This word is still processing from an older app flow.',
      SubmittedWordStatus.ready => submission.resolutionType ==
              SubmittedWordResolutionType.existingWord
          ? 'This word already exists. It was added and counted as one learned item.'
          : 'Word created and added to your study list. Counted as one learned item.',
      SubmittedWordStatus.failed => submission.failureReason ??
          'The app could not prepare this word right now. Please try again.',
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
                  children: [
                    Text(
                      'Add a word instantly',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If you find an unfamiliar word while reading, type it here. '
                      'If the word already exists, the app returns it immediately. '
                      'If it does not, the backend generates it now, saves it, and adds it to your normal study flow as one learned item.',
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
                        label: Text(_isSubmitting ? 'Adding...' : 'Add word'),
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
      SubmittedWordStatus.queued => 'Pending (legacy)',
      SubmittedWordStatus.processing => 'Processing (legacy)',
      SubmittedWordStatus.ready => submission.resolutionType ==
              SubmittedWordResolutionType.existingWord
          ? 'Added (already existed)'
          : 'Added now',
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
