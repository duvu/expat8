import 'package:flutter/material.dart';

import '../data/article_repository.dart';
import '../models/article.dart';

const Map<String, String> kArticleLanguageLabels = {
  'en': 'English',
  'zh': 'Chinese',
  'vi': 'Vietnamese',
};

class ArticleManagementScreen extends StatefulWidget {
  const ArticleManagementScreen({
    required this.repository,
    required this.sessionToken,
    required this.initialLanguage,
    required this.supportedLanguages,
    super.key,
  });

  final ArticleRepository repository;
  final String sessionToken;
  final String initialLanguage;
  final List<String> supportedLanguages;

  @override
  State<ArticleManagementScreen> createState() => _ArticleManagementScreenState();
}

class _ArticleManagementScreenState extends State<ArticleManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ManagedArticle> _articles = const [];

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final articles = await widget.repository.listArticles(
        sessionToken: widget.sessionToken,
      );
      if (!mounted) return;
      setState(() {
        _articles = articles;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateArticle() async {
    final created = await Navigator.of(context).push<ManagedArticle>(
      MaterialPageRoute(
        builder: (_) => ArticleCreateScreen(
          repository: widget.repository,
          sessionToken: widget.sessionToken,
          initialLanguage: widget.initialLanguage,
          supportedLanguages: widget.supportedLanguages,
        ),
      ),
    );
    if (!mounted || created == null) return;
    await _loadArticles();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Article created.')),
    );
  }

  Future<void> _openArticleDetail(ManagedArticle article) async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(
          repository: widget.repository,
          sessionToken: widget.sessionToken,
          articleId: article.id,
        ),
      ),
    );
    if (removed == true && mounted) {
      await _loadArticles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article deleted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Articles'),
        actions: [
          IconButton(
            tooltip: 'Refresh articles',
            onPressed: _isLoading ? null : _loadArticles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateArticle,
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadArticles,
        child: _isLoading
            ? ListView(
                children: [
                  SizedBox(height: 160),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _errorMessage != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load articles.',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton.icon(
                          onPressed: _loadArticles,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ),
                    ],
                  )
                : _articles.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 56,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No articles yet.',
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create a text article to start extracting vocabulary.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                        itemCount: _articles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final article = _articles[index];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              leading: Icon(
                                _statusIcon(article.status),
                                color: _statusColor(context, article.status),
                              ),
                              title: Text(article.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_languageLabel(article.language)} • ${_statusLabel(article.status)} • ${_formatDate(article.createdAt)}',
                                  ),
                                  if (article.processingError != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      article.processingError!,
                                      style: TextStyle(
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openArticleDetail(article),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class ArticleCreateScreen extends StatefulWidget {
  const ArticleCreateScreen({
    required this.repository,
    required this.sessionToken,
    required this.initialLanguage,
    required this.supportedLanguages,
    super.key,
  });

  final ArticleRepository repository;
  final String sessionToken;
  final String initialLanguage;
  final List<String> supportedLanguages;

  @override
  State<ArticleCreateScreen> createState() => _ArticleCreateScreenState();
}

class _ArticleCreateScreenState extends State<ArticleCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  final _rawTextController = TextEditingController();
  bool _isSubmitting = false;
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    final supported = widget.supportedLanguages;
    _selectedLanguage = supported.contains(widget.initialLanguage)
        ? widget.initialLanguage
        : (supported.isNotEmpty ? supported.first : 'en');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sourceUrlController.dispose();
    _rawTextController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final created = await widget.repository.createArticle(
        sessionToken: widget.sessionToken,
        title: _titleController.text.trim(),
        language: _selectedLanguage,
        rawText: _rawTextController.text,
        sourceUrl: _sourceUrlController.text.trim().isEmpty
            ? null
            : _sourceUrlController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create article: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languages = widget.supportedLanguages.isEmpty
        ? const ['en']
        : widget.supportedLanguages;
    return Scaffold(
      appBar: AppBar(title: const Text('Create article')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(
                'Paste article text and let the backend extract vocabulary.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('article_create_title'),
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Title is required.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: const InputDecoration(labelText: 'Language'),
                items: languages
                    .map(
                      (language) => DropdownMenuItem<String>(
                        value: language,
                        child: Text(_languageLabel(language)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedLanguage = value);
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('article_create_source_url'),
                controller: _sourceUrlController,
                decoration: const InputDecoration(
                  labelText: 'Source URL (optional)',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('article_create_raw_text'),
                controller: _rawTextController,
                decoration: const InputDecoration(
                  labelText: 'Article text',
                  alignLabelWithHint: true,
                ),
                maxLines: 12,
                minLines: 8,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Article text is required.'
                    : null,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('article_create_submit'),
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish),
                label: Text(_isSubmitting ? 'Creating...' : 'Create article'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({
    required this.repository,
    required this.sessionToken,
    required this.articleId,
    super.key,
  });

  final ArticleRepository repository;
  final String sessionToken;
  final String articleId;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorMessage;
  ManagedArticle? _article;
  ArticleVocabularyResponse? _vocabulary;

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  Future<void> _loadArticle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final article = await widget.repository.getArticle(
        sessionToken: widget.sessionToken,
        articleId: widget.articleId,
      );
      final vocabulary = await widget.repository.getArticleVocabulary(
        sessionToken: widget.sessionToken,
        articleId: widget.articleId,
      );
      if (!mounted) return;
      setState(() {
        _article = article;
        _vocabulary = vocabulary;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteArticle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete article?'),
        content: const Text(
          'This removes the article and its extracted vocabulary from the list view.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || _article == null) return;
    setState(() => _isDeleting = true);
    try {
      await widget.repository.deleteArticle(
        sessionToken: widget.sessionToken,
        articleId: _article!.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete article: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article detail'),
        actions: [
          IconButton(
            tooltip: 'Refresh article',
            onPressed: _isLoading ? null : _loadArticle,
            icon: const Icon(Icons.refresh),
          ),
          if (_article != null)
            IconButton(
              tooltip: 'Delete article',
              onPressed: _isLoading || _isDeleting ? null : _deleteArticle,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_errorMessage!, textAlign: TextAlign.center),
                  ),
                )
              : _article == null
                  ? const Center(child: Text('Article not found.'))
                  : RefreshIndicator(
                      onRefresh: _loadArticle,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            _article!.title,
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaChip(label: _languageLabel(_article!.language)),
                              _MetaChip(label: _statusLabel(_article!.status)),
                              _MetaChip(label: _article!.visibility),
                              _MetaChip(label: _formatDate(_article!.createdAt)),
                            ],
                          ),
                          if (_article!.sourceUrl != null) ...[
                            const SizedBox(height: 16),
                            Text('Source URL', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text(_article!.sourceUrl!),
                          ],
                          if (_article!.processingError != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Processing error',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(color: theme.colorScheme.error),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _article!.processingError!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Text('Vocabulary', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          if ((_vocabulary?.items ?? const []).isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text('No vocabulary has been extracted yet.'),
                            )
                          else
                            ..._vocabulary!.items.map(
                              (item) => Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.displayTerm,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(item.meaningVi),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (item.level != null)
                                            _MetaChip(label: item.level!),
                                          _MetaChip(label: item.status),
                                          if (item.classification != null)
                                            _MetaChip(label: item.classification!),
                                          if (item.suggestionType != null)
                                            _MetaChip(label: item.suggestionType!),
                                        ],
                                      ),
                                      if (item.partOfSpeech != null ||
                                          item.ipa != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          [
                                            if (item.partOfSpeech != null)
                                              item.partOfSpeech,
                                            if (item.ipa != null) item.ipa,
                                          ].join(' • '),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}

String _languageLabel(String language) {
  return kArticleLanguageLabels[language] ?? language.toUpperCase();
}

String _statusLabel(String status) {
  return status.replaceAll('_', ' ');
}

IconData _statusIcon(String status) {
  return switch (status) {
    'processing' => Icons.sync,
    'pending_processing' => Icons.schedule,
    'pending_review' => Icons.rate_review_outlined,
    'published' => Icons.public,
    'processed' => Icons.check_circle_outline,
    'deleted' => Icons.delete_outline,
    _ => Icons.article_outlined,
  };
}

Color _statusColor(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    'published' => scheme.primary,
    'processed' => scheme.tertiary,
    'processing' => scheme.secondary,
    'pending_review' => scheme.secondary,
    'deleted' => scheme.outline,
    'pending_processing' => scheme.outline,
    _ => scheme.outline,
  };
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final iso = local.toIso8601String();
  return iso.length >= 16 ? iso.substring(0, 16).replaceFirst('T', ' ') : iso;
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
