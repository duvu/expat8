import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/shadowing_repository.dart';
import '../models/shadowing_video.dart';
import 'shadowing_player_screen.dart';

/// Displays the curated and saved shadowing video library.
/// Also allows importing a new video by YouTube URL.
class ShadowingLibraryScreen extends StatefulWidget {
  const ShadowingLibraryScreen({
    required this.repository,
    super.key,
  });

  final ShadowingRepository repository;

  @override
  State<ShadowingLibraryScreen> createState() => _ShadowingLibraryScreenState();
}

class _ShadowingLibraryScreenState extends State<ShadowingLibraryScreen> {
  List<ShadowingVideo> _videos = [];
  bool _isLoading = false;
  bool _isImporting = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    // Show cached items immediately.
    final cached = widget.repository.listCachedVideos();
    if (mounted) {
      setState(() {
        _videos = cached;
        _isLoading = cached.isEmpty;
      });
    }
    // Refresh from backend in background.
    try {
      final refreshed = await widget.repository.refreshLibrary();
      if (mounted) {
        setState(() {
          _videos = refreshed;
          _isLoading = false;
          _loadFailed = false;
        });
      }
    } catch (e) {
      debugPrint('[ShadowingLibraryScreen] refreshLibrary failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_videos.isEmpty) _loadFailed = true;
        });
      }
    }
  }

  Future<void> _showImportDialog() async {
    final urlController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import YouTube video'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: 'https://www.youtube.com/watch?v=...',
            labelText: 'YouTube URL',
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(urlController.text.trim()),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    await _importVideo(result);
  }

  Future<void> _importVideo(String url) async {
    setState(() => _isImporting = true);
    try {
      final video = await widget.repository.importVideo(sourceUrl: url);
      if (mounted) {
        setState(() {
          _isImporting = false;
          // Insert at top of list (most recently added).
          _videos = [video, ..._videos.where((v) => v.id != video.id)];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported: ${video.title}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        final message = _importErrorMessage(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  String _importErrorMessage(String error) {
    if (error.contains('transcript_unavailable')) {
      return 'No transcript available for this video. Please try another.';
    }
    if (error.contains('shadowing_import_failed')) {
      return 'Could not import this video. Please check the URL and try again.';
    }
    return 'Import failed. Please try again.';
  }

  void _openPlayer(ShadowingVideo video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShadowingPlayerScreen(
          video: video,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final curated = _videos.where((v) => v.isCurated).toList();
    final saved = _videos.where((v) => !v.isCurated).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Shadowing'),
        actions: [
          if (_isImporting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_link),
              tooltip: 'Import YouTube video',
              onPressed: _showImportDialog,
            ),
        ],
      ),
      body: _buildBody(curated, saved),
    );
  }

  Widget _buildBody(
      List<ShadowingVideo> curated, List<ShadowingVideo> saved) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadFailed && _videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              "Couldn't load videos.\nCheck your connection and try again.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadLibrary,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No videos yet.\nImport a YouTube video to get started.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showImportDialog,
              icon: const Icon(Icons.add_link),
              label: const Text('Import video'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadLibrary,
      child: ListView(
        children: [
          if (curated.isNotEmpty) ...[
            const _SectionHeader(title: 'Curated'),
            ...curated.map((v) => _VideoTile(video: v, onTap: () => _openPlayer(v))),
          ],
          if (saved.isNotEmpty) ...[
            const _SectionHeader(title: 'My Videos'),
            ...saved.map((v) => _VideoTile(video: v, onTap: () => _openPlayer(v))),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.video, required this.onTap});

  final ShadowingVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _Thumbnail(url: video.thumbnailUrl),
      title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: video.channelTitle != null
          ? Text(video.channelTitle!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Text(
        video.segmentCount > 0
            ? '${video.segmentCount} lines'
            : '',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onTap,
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return const SizedBox(
        width: 80,
        height: 45,
        child: ColoredBox(
          color: Colors.black12,
          child: Icon(Icons.ondemand_video, size: 32),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url!,
        width: 80,
        height: 45,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 80,
          height: 45,
          child: ColoredBox(
            color: Colors.black12,
            child: Icon(Icons.ondemand_video, size: 32),
          ),
        ),
      ),
    );
  }
}
