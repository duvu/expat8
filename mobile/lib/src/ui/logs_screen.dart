import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../logging/logger.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import 'log_share_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({
    required this.repository,
    this.shareService = const PlatformLogShareService(),
    super.key,
  });

  final WordRepository repository;
  final LogShareService shareService;

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  AppLogLevel _minimumLevel = AppLogLevel.warning;
  AppLogCategory? _category;
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isSending = false;
  List<LogEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await widget.repository.loadLogs(
      minimumLevel: _minimumLevel,
      category: _category,
      limit: 300,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = logs;
      _isLoading = false;
    });
  }

  Future<void> _exportLogs() async {
    setState(() => _isExporting = true);
    try {
      final result = await widget.repository.exportLogs(
        minimumLevel: _minimumLevel,
        category: _category,
        limit: 2000,
      );
      if (!mounted) {
        return;
      }
      if (result.count == 0) {
        _showSnackBar('No logs to export for selected filters.');
        return;
      }
      final shareResult = await widget.shareService.share(
        result,
        sharePositionOrigin: _sharePositionOrigin(),
      );
      if (!mounted) {
        return;
      }
      _showSnackBar(_shareMessage(shareResult, result.count));
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Failed to share logs: $error');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _sendLogsToServer() async {
    setState(() => _isSending = true);
    try {
      final result = await widget.repository.sendLogsToServer(
        minimumLevel: _minimumLevel,
        category: _category,
        limit: 2000,
      );
      if (!mounted) {
        return;
      }
      if (result.count == 0) {
        _showSnackBar('No logs to send to the server.');
        return;
      }
      _showSnackBar('Sent ${result.count} logs to the server.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Failed to send logs to server: $error');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Rect? _sharePositionOrigin() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  String _shareMessage(LogShareOutcome result, int count) {
    return switch (result.status) {
      LogShareStatus.success => 'Shared $count logs.',
      LogShareStatus.dismissed => 'Log share dismissed.',
      LogShareStatus.unavailable =>
        'Log sharing is unavailable on this device.',
    };
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Logs'),
        actions: [
          IconButton(
            tooltip: 'Refresh logs',
            onPressed: _isLoading ? null : _loadLogs,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Send logs to server',
            onPressed: (_isLoading || _isExporting || _isSending)
                ? null
                : _sendLogsToServer,
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
          ),
          IconButton(
            tooltip: 'Export logs',
            onPressed: (_isLoading || _isExporting || _isSending)
                ? null
                : _exportLogs,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<AppLogLevel>(
                    value: _minimumLevel,
                    decoration:
                        const InputDecoration(labelText: 'Minimum Level'),
                    items: AppLogLevel.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name.toUpperCase()),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _minimumLevel = value);
                      _loadLogs();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<AppLogCategory?>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem<AppLogCategory?>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ...AppLogCategory.values.map(
                        (value) => DropdownMenuItem<AppLogCategory?>(
                          value: value,
                          child: Text(value.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _category = value);
                      _loadLogs();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.notes,
                        title: 'No logs',
                        body: 'No log entries match the selected filters.',
                      )
                    : ListView.separated(
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          final subtitle = [
                            '${entry.timestamp.toLocal()} | ${entry.category.name} | ${entry.event}',
                            entry.context.isEmpty
                                ? null
                                : entry.context.toString(),
                          ].whereType<String>().join('\n');
                          return ListTile(
                            dense: true,
                            leading: _SeverityDot(level: entry.level),
                            title: Text(entry.message),
                            subtitle: Text(subtitle),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SeverityDot extends StatelessWidget {
  const _SeverityDot({required this.level});

  final AppLogLevel level;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final color = switch (level) {
      AppLogLevel.debug => appColors.severityDebug,
      AppLogLevel.info => appColors.severityInfo,
      AppLogLevel.warning => appColors.severityWarn,
      AppLogLevel.error => appColors.severityError,
    };
    return Icon(Icons.circle, size: 10, color: color);
  }
}
