import 'package:flutter/material.dart';

import '../data/memorization_repository.dart';
import '../models/memorization_passage.dart';
import '../models/user_session.dart';

/// Main memorization passages list screen.
class MemorizationScreen extends StatefulWidget {
  const MemorizationScreen({
    super.key,
    required this.repository,
    required this.userSession,
  });

  final MemorizationRepository repository;
  final UserSession userSession;

  @override
  State<MemorizationScreen> createState() => _MemorizationScreenState();
}

class _MemorizationScreenState extends State<MemorizationScreen> {
  List<MemorizationPassage> _passages = [];
  Map<String, _PassageProgressSummary> _progressByPassageId = const {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPassages();
  }

  Future<void> _loadPassages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final passages = await widget.repository.listPassages(
        sessionToken: widget.userSession.sessionToken,
      );
      final progressEntries = await Future.wait(
        passages.map((passage) async {
          if (passage.segmentCount <= 0) {
            return MapEntry(passage.id, const _PassageProgressSummary.empty());
          }
          final progress = await widget.repository.getPassageProgress(
            sessionToken: widget.userSession.sessionToken,
            passageId: passage.id,
          );
          return MapEntry(
            passage.id,
            _PassageProgressSummary.fromProgress(
              progress,
              totalSegments: passage.segmentCount,
            ),
          );
        }),
      );
      if (!mounted) return;
      setState(() {
        _passages = passages;
        _progressByPassageId = Map.fromEntries(progressEntries);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load passages: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PassageCreateScreen(
          repository: widget.repository,
          userSession: widget.userSession,
        ),
      ),
    );
    if (created == true) {
      _loadPassages();
    }
  }

  Future<void> _openDetail(MemorizationPassage passage) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PassageDetailScreen(
          repository: widget.repository,
          userSession: widget.userSession,
          passageId: passage.id,
        ),
      ),
    );
    if (deleted == true) {
      _loadPassages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final myPassages = _passages
        .where((passage) => passage.ownerUserId == widget.userSession.userId)
        .toList();
    final featuredPassages = _passages
        .where((passage) => passage.ownerUserId != widget.userSession.userId)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Memorization')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPassages,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPassages,
                  child: _passages.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(
                              child: Text(
                                'No passages yet.\nTap + to create one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey),
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          children: [
                            _PassageSection(
                              title: 'My Passages',
                              passages: myPassages,
                              progressByPassageId: _progressByPassageId,
                              onTap: _openDetail,
                              statusIconBuilder: _statusIcon,
                            ),
                            _PassageSection(
                              title: 'Featured',
                              passages: featuredPassages,
                              progressByPassageId: _progressByPassageId,
                              onTap: _openDetail,
                              statusIconBuilder: _statusIcon,
                            ),
                          ],
                        ),
                ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'published':
      case 'segmented':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'segmenting':
      case 'pending_segmentation':
        return const Icon(Icons.hourglass_empty, color: Colors.orange);
      case 'failed':
        return const Icon(Icons.error, color: Colors.red);
      default:
        return const Icon(Icons.circle_outlined, color: Colors.grey);
    }
  }
}

class _PassageSection extends StatelessWidget {
  const _PassageSection({
    required this.title,
    required this.passages,
    required this.progressByPassageId,
    required this.onTap,
    required this.statusIconBuilder,
  });

  final String title;
  final List<MemorizationPassage> passages;
  final Map<String, _PassageProgressSummary> progressByPassageId;
  final ValueChanged<MemorizationPassage> onTap;
  final Widget Function(String status) statusIconBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (passages.isEmpty)
            Text(
              title == 'My Passages'
                  ? 'Create your first passage with the + button.'
                  : 'No featured passages are available yet.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            )
          else
            ...passages.map(
              (passage) => _PassageListTile(
                passage: passage,
                progress: progressByPassageId[passage.id] ??
                    const _PassageProgressSummary.empty(),
                trailing: statusIconBuilder(passage.status),
                onTap: () => onTap(passage),
              ),
            ),
        ],
      ),
    );
  }
}

class _PassageListTile extends StatelessWidget {
  const _PassageListTile({
    required this.passage,
    required this.progress,
    required this.trailing,
    required this.onTap,
  });

  final MemorizationPassage passage;
  final _PassageProgressSummary progress;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(passage.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${passage.language.toUpperCase()} · '
              '${passage.segmentCount} segments · '
              '${_statusLabel(passage.status)}',
            ),
            if (passage.segmentCount > 0) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress.percentage / 100),
              const SizedBox(height: 4),
              Text('${progress.percentage}% memorized'),
            ],
          ],
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _PassageProgressSummary {
  const _PassageProgressSummary({required this.percentage});

  const _PassageProgressSummary.empty() : percentage = 0;

  factory _PassageProgressSummary.fromProgress(
    List<MemorizationSegmentProgress> progress, {
    required int totalSegments,
  }) {
    if (totalSegments <= 0) {
      return const _PassageProgressSummary.empty();
    }
    final completed = progress
        .where((entry) => entry.status == 'review' || entry.status == 'mastered')
        .length;
    return _PassageProgressSummary(
      percentage: ((completed / totalSegments) * 100).round(),
    );
  }

  final int percentage;
}

String _statusLabel(String status) {
  switch (status) {
    case 'pending_segmentation':
      return 'pending segmentation';
    case 'segmenting':
      return 'segmenting';
    case 'segmented':
      return 'ready';
    case 'published':
      return 'published';
    case 'failed':
      return 'failed';
    default:
      return status;
  }
}

/// Create a new memorization passage.
class PassageCreateScreen extends StatefulWidget {
  const PassageCreateScreen({
    super.key,
    required this.repository,
    required this.userSession,
  });

  final MemorizationRepository repository;
  final UserSession userSession;

  @override
  State<PassageCreateScreen> createState() => _PassageCreateScreenState();
}

class _PassageCreateScreenState extends State<PassageCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  String _language = 'en';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.repository.createPassage(
        sessionToken: widget.userSession.sessionToken,
        title: _titleController.text.trim(),
        language: _language,
        rawText: _textController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passage created!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Passage')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. I Have a Dream',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _language,
                decoration: const InputDecoration(labelText: 'Language'),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                  DropdownMenuItem(value: 'vi', child: Text('Vietnamese')),
                ],
                onChanged: (v) => setState(() => _language = v ?? 'en'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Passage Text',
                  hintText:
                      'Paste the full passage here (50-20000 characters)...',
                  alignLabelWithHint: true,
                ),
                maxLines: 12,
                validator: (v) {
                  if (v == null || v.trim().length < 50) {
                    return 'Text must be at least 50 characters';
                  }
                  if (v.trim().length > 20000) {
                    return 'Text must be at most 20000 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Passage'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail view of a memorization passage with its segments.
class PassageDetailScreen extends StatefulWidget {
  const PassageDetailScreen({
    super.key,
    required this.repository,
    required this.userSession,
    required this.passageId,
  });

  final MemorizationRepository repository;
  final UserSession userSession;
  final String passageId;

  @override
  State<PassageDetailScreen> createState() => _PassageDetailScreenState();
}

class _PassageDetailScreenState extends State<PassageDetailScreen> {
  MemorizationPassage? _passage;
  List<MemorizationSegmentProgress> _progress = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPassage();
  }

  Future<void> _loadPassage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        widget.repository.getPassage(
          sessionToken: widget.userSession.sessionToken,
          passageId: widget.passageId,
        ),
        widget.repository.getPassageProgress(
          sessionToken: widget.userSession.sessionToken,
          passageId: widget.passageId,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _passage = results[0] as MemorizationPassage;
        _progress = results[1] as List<MemorizationSegmentProgress>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load passage: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePassage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Passage'),
        content: const Text('Are you sure you want to delete this passage?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deletePassage(
        sessionToken: widget.userSession.sessionToken,
        passageId: widget.passageId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passage deleted')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_passage?.title ?? 'Passage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deletePassage,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final passage = _passage!;
    final segments = passage.segments ?? [];
    final progressMap = {for (final p in _progress) p.segmentId: p};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Metadata
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(passage.title,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '${passage.language.toUpperCase()} · ${passage.status} · '
                  '${passage.segmentCount} segments',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Segments
        if (segments.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No segments yet. The passage is being processed...',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...segments.map((segment) {
            final prog = progressMap[segment.id];
            return _SegmentCard(
              segment: segment,
              progress: prog,
            );
          }),
      ],
    );
  }
}

/// Segment card with interlinear IPA / translation toggles.
class _SegmentCard extends StatefulWidget {
  const _SegmentCard({required this.segment, this.progress});

  final MemorizationSegment segment;
  final MemorizationSegmentProgress? progress;

  @override
  State<_SegmentCard> createState() => _SegmentCardState();
}

class _SegmentCardState extends State<_SegmentCard> {
  bool _showIpa = false;
  bool _showTranslation = false;
  bool _showVietReading = false;

  @override
  Widget build(BuildContext context) {
    final segment = widget.segment;
    final prog = widget.progress;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: position badge + word count + toggle buttons + progress chip
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  child: Text(
                    '${segment.position + 1}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${segment.wordCount} words',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const Spacer(),
                if (segment.ipaText != null)
                  _ToggleButton(
                    active: _showIpa,
                    icon: Icons.record_voice_over_outlined,
                    tooltip: 'IPA',
                    onTap: () => setState(() => _showIpa = !_showIpa),
                  ),
                if (segment.translationText != null)
                  _ToggleButton(
                    active: _showTranslation,
                    icon: Icons.translate,
                    tooltip: 'Translation',
                    onTap: () =>
                        setState(() => _showTranslation = !_showTranslation),
                  ),
                if (segment.vietReadingText != null)
                  _ToggleButton(
                    active: _showVietReading,
                    icon: Icons.spellcheck,
                    tooltip: 'Cách đọc',
                    onTap: () =>
                        setState(() => _showVietReading = !_showVietReading),
                  ),
                if (prog != null) ...[
                  const SizedBox(width: 6),
                  Chip(
                    label: Text(prog.status,
                        style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Original text (always shown)
            Text(segment.text),
            // IPA row (interlinear — below text, not replacing it)
            if (_showIpa && segment.ipaText != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  segment.ipaText!,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onPrimaryContainer,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
            // Translation row (interlinear — below text, not replacing it)
            if (_showTranslation && segment.translationText != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  segment.translationText!,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
            // Viet reading row (interlinear — cách đọc)
            if (_showVietReading && segment.vietReadingText != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  segment.vietReadingText!,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onTertiaryContainer,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.active,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 18,
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

