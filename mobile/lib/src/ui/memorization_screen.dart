import 'package:flutter/material.dart';

import '../data/memorization_repository.dart';
import '../models/memorization_passage.dart';
import '../models/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/language_picker.dart';
import 'memorization_drill_screen.dart';

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
  bool _showingCached = false;
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
      final result = await widget.repository.loadPassages(
        sessionToken: widget.userSession.sessionToken,
      );
      final passages = result.data;
      final progressEntries = await Future.wait(
        passages.map((passage) async {
          if (passage.segmentCount <= 0) {
            return MapEntry(passage.id, const _PassageProgressSummary.empty());
          }
          final progress = await widget.repository.loadPassageProgress(
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
        _showingCached = result.fromCache;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load passages. Check your connection.';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('New passage'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? EmptyStateView(
                  icon: Icons.error_outline,
                  title: 'Could not load passages',
                  body: _errorMessage,
                  actionLabel: 'Retry',
                  onAction: _loadPassages,
                )
              : RefreshIndicator(
                  onRefresh: _loadPassages,
                  child: _passages.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            EmptyStateView(
                              icon: Icons.menu_book_outlined,
                              title: 'No passages yet',
                              body:
                                  'Tap “New passage” to add a text you want to learn by heart.',
                            ),
                          ],
                        )
                      : ListView(
                          children: [
                            if (_showingCached)
                              const ListTile(
                                dense: true,
                                leading: Icon(Icons.cloud_off, size: 20),
                                title: Text(
                                  'Offline — showing passages saved on this device.',
                                ),
                              ),
                            _PassageSection(
                              title: 'My passages',
                              passages: myPassages,
                              progressByPassageId: _progressByPassageId,
                              onTap: _openDetail,
                              statusIconBuilder: _statusIcon,
                            ),
                            _PassageSection(
                              title: 'Recommended',
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
    final appColors = AppColors.of(context);
    switch (status) {
      case 'published':
      case 'segmented':
        return Icon(Icons.check_circle, color: appColors.statusSuccess);
      case 'segmenting':
      case 'pending_segmentation':
        return Icon(Icons.hourglass_empty, color: appColors.statusWarning);
      case 'failed':
        return Icon(Icons.error, color: appColors.statusError);
      default:
        return Icon(Icons.circle_outlined, color: appColors.statusNeutral);
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
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (passages.isEmpty)
            Text(
              title == 'My passages'
                  ? 'Tap “New passage” to add your first one.'
                  : 'No recommended passages yet.',
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
    final theme = Theme.of(context);
    final ready = passage.status == 'segmented' ||
        passage.status == 'published' ||
        passage.status == 'ready';
    final percent = progress.percentage;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        title: Text(passage.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              if (passage.segmentCount > 0)
                '${passage.segmentCount} ${passage.segmentCount == 1 ? 'part' : 'parts'}',
              languageName(passage.language),
              if (!ready) _statusLabel(passage.status),
            ].join(' · '),
          ),
        ),
        trailing: ready && passage.segmentCount > 0
            ? Semantics(
                label: '$percent% memorized',
                excludeSemantics: true,
                child: SizedBox.square(
                  dimension: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: percent / 100,
                        strokeWidth: 5,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                      Text('$percent%',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              )
            : trailing,
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
        .where(
            (entry) => entry.status == 'review' || entry.status == 'mastered')
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
    case 'segmenting':
      return 'Preparing…';
    case 'segmented':
    case 'ready':
      return 'Ready';
    case 'published':
      return 'Published';
    case 'failed':
      return 'Could not prepare';
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
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 16),
              LanguagePicker(
                languages: const ['en', 'zh', 'vi'],
                selected: _language,
                onChanged: (v) => setState(() => _language = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Text to memorize',
                  hintText:
                      'Paste a speech, dialogue or paragraph (at least 50 characters)',
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
              FilledButton(
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
        widget.repository.loadPassageProgress(
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
        _errorMessage = 'This passage is not saved on this device yet. '
            'Open it once while online to use it offline.';
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

  Future<void> _startDrill() async {
    final passage = _passage;
    if (passage == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MemorizationDrillScreen(
          passage: passage,
          repository: widget.repository,
          userSession: widget.userSession,
        ),
      ),
    );
    // Refresh progress after drill
    _loadPassage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_passage?.title ?? 'Passage'),
        actions: [
          IconButton(
            tooltip: 'Delete passage',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deletePassage,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? EmptyStateView(
                  icon: Icons.error_outline,
                  title: 'Could not load passage',
                  body: _errorMessage,
                  actionLabel: 'Retry',
                  onAction: _loadPassage,
                )
              : _buildContent(),
      floatingActionButton:
          _passage != null && (_passage!.segments?.isNotEmpty ?? false)
              ? FloatingActionButton.extended(
                  onPressed: _startDrill,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Practice'),
                )
              : null,
    );
  }

  Widget _buildContent() {
    final passage = _passage!;
    final segments = passage.segments ?? [];
    final progressMap = {for (final p in _progress) p.segmentId: p};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          [
            '${passage.segmentCount} ${passage.segmentCount == 1 ? 'part' : 'parts'}',
            languageName(passage.language),
          ].join(' · '),
          style: TextStyle(color: AppColors.of(context).subtleText),
        ),
        const SizedBox(height: 4),
        Text(
          'Read each part aloud. Tap IPA, Meaning or Reading for help.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.of(context).subtleText,
              ),
        ),
        const SizedBox(height: 12),

        // Segments
        if (segments.isEmpty)
          Builder(
            builder: (context) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'This passage is still being prepared. Pull down or come back in a minute.',
                  style: TextStyle(color: AppColors.of(context).subtleText),
                ),
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
                  style: TextStyle(
                      color: AppColors.of(context).subtleText, fontSize: 12),
                ),
                const Spacer(),
                if (prog != null) _ProgressBadge(status: prog.status),
              ],
            ),
            const SizedBox(height: 8),
            // Original text (always shown)
            Text(segment.text, style: theme.textTheme.titleMedium),
            if (segment.ipaText != null ||
                segment.translationText != null ||
                segment.vietReadingText != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  if (segment.ipaText != null)
                    FilterChip(
                      label: const Text('IPA'),
                      selected: _showIpa,
                      onSelected: (v) => setState(() => _showIpa = v),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (segment.translationText != null)
                    FilterChip(
                      label: const Text('Meaning'),
                      selected: _showTranslation,
                      onSelected: (v) => setState(() => _showTranslation = v),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (segment.vietReadingText != null)
                    FilterChip(
                      label: const Text('Reading'),
                      selected: _showVietReading,
                      onSelected: (v) => setState(() => _showVietReading = v),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            // IPA row (interlinear — below text, not replacing it)
            if (_showIpa && segment.ipaText != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.35),
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
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer
                      .withValues(alpha: 0.4),
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
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer
                      .withValues(alpha: 0.4),
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

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (String label, Color bg, Color fg) = switch (status) {
      'memorized' || 'mastered' => (
          'Memorized',
          scheme.primaryContainer,
          scheme.onPrimaryContainer
        ),
      'learning' => (
          'Learning',
          scheme.secondaryContainer,
          scheme.onSecondaryContainer
        ),
      'review' || 'reviewing' => (
          'Reviewing',
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer
        ),
      _ => ('New', scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
