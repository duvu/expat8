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
    _selectedLanguage =
        widget.supportedLanguages.contains(widget.initialLanguage)
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
        'Saved offline. It will be added automatically when you are back online.',
      SubmittedWordStatus.queued =>
        'This word is still pending from an older app flow.',
      SubmittedWordStatus.processing =>
        'This word is still processing from an older app flow.',
      SubmittedWordStatus.ready => submission.resolutionType ==
              SubmittedWordResolutionType.existingWord
          ? 'This word already exists. It was added and counted as one learned item.'
          : 'Word created and added to your study list. Counted as one learned item.',
      SubmittedWordStatus.failed =>
        'The server could not use this word. Check the spelling and try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add word'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Found a new word?',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type it below and it joins your study cards. Works offline too.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _termController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _isSubmitting ? null : _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Word or short expression',
                        hintText: 'e.g. reliable',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                    ),
                    if (widget.supportedLanguages.length > 1) ...[
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: [
                          for (final language in widget.supportedLanguages)
                            ButtonSegment(
                                value: language,
                                label: Text(_labelFor(language))),
                        ],
                        selected: {_selectedLanguage},
                        showSelectedIcon: false,
                        onSelectionChanged: _isSubmitting
                            ? null
                            : (value) =>
                                setState(() => _selectedLanguage = value.first),
                      ),
                    ],
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
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Your words',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                if (_items.isNotEmpty)
                  Text('${_items.length}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: scheme.outline)),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.bookmark_add_outlined,
                        size: 40, color: scheme.outline),
                    const SizedBox(height: 8),
                    Text(
                      'Words you add will show up here.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meaning = submission.status == SubmittedWordStatus.ready
        ? submission.resolvedWord?.meaningVi
        : null;
    final (Color bg, Color fg) = switch (submission.status) {
      SubmittedWordStatus.ready => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer
        ),
      SubmittedWordStatus.failed => (
          scheme.errorContainer,
          scheme.onErrorContainer
        ),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    final details = [
      if (meaning != null) meaning,
      if (submission.failureReason != null &&
          submission.failureReason!.isNotEmpty)
        submission.failureReason!,
      _labelFor(submission.targetLanguage),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bg,
          foregroundColor: fg,
          child: Icon(_statusIcon(submission.status), size: 20),
        ),
        title: Text(submission.submittedTerm,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${_statusLabel(submission)}\n$details'),
        isThreeLine: true,
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
      SubmittedWordStatus.queuedSync => 'Waiting for connection',
      SubmittedWordStatus.queued => 'Pending (legacy)',
      SubmittedWordStatus.processing => 'Processing (legacy)',
      SubmittedWordStatus.ready =>
        submission.resolutionType == SubmittedWordResolutionType.existingWord
            ? 'Added (already existed)'
            : 'Added to your cards',
      SubmittedWordStatus.failed => 'Could not add',
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
