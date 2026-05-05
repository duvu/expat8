import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../logging/logger.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({required this.repository, super.key});

  final WordRepository repository;

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  AppLogLevel _minimumLevel = AppLogLevel.warning;
  AppLogCategory? _category;
  bool _isLoading = true;
  bool _isExporting = false;
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
    final result = await widget.repository.exportLogs(
      minimumLevel: _minimumLevel,
      category: _category,
      limit: 2000,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isExporting = false);
    final path = result.path ?? 'in-memory payload';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${result.count} logs to $path'),
      ),
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
            tooltip: 'Export logs',
            onPressed: _isExporting ? null : _exportLogs,
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
                    decoration: const InputDecoration(labelText: 'Minimum Level'),
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
                    ? const Center(child: Text('No logs for selected filters.'))
                    : ListView.separated(
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          final subtitle = [
                            '${entry.timestamp.toLocal()} | ${entry.category.name} | ${entry.event}',
                            entry.context.isEmpty ? null : entry.context.toString(),
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
    final color = switch (level) {
      AppLogLevel.debug => Colors.blueGrey,
      AppLogLevel.info => Colors.blue,
      AppLogLevel.warning => Colors.orange,
      AppLogLevel.error => Colors.red,
    };
    return Icon(Icons.circle, size: 10, color: color);
  }
}
