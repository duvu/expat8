import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/backend_api_client.dart';
import '../data/local_database.dart';

/// Public certificate view screen.
///
/// Fetches the certificate from the backend using [certificateId] and renders
/// it. No authentication required — the endpoint is public.
///
/// Requires [BackendApiClient] to be accessible. The screen resolves it by
/// accepting it as a constructor parameter so it can be opened from both
/// within the exam flow and via deep link navigation.
class ExamCertificateScreen extends StatefulWidget {
  const ExamCertificateScreen({
    required this.certificateId,
    this.apiClient,
    super.key,
  });

  final String certificateId;

  /// If null, the screen will be constructed with the app's global client
  /// injected via InheritedWidget or similar. For simplicity this version
  /// accepts a direct reference.
  final BackendApiClient? apiClient;

  @override
  State<ExamCertificateScreen> createState() => _ExamCertificateScreenState();
}

class _ExamCertificateScreenState extends State<ExamCertificateScreen> {
  ExamCertificate? _cert;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = widget.apiClient;
    if (client == null) {
      setState(() {
        _loading = false;
        _error = 'API client not available.';
      });
      return;
    }
    try {
      final cert = await client.fetchExamCertificate(
          certificateId: widget.certificateId);
      if (!mounted) return;
      setState(() {
        _cert = cert;
        _loading = false;
      });
    } on BackendApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.statusCode == 404
            ? 'Certificate not found.'
            : 'Failed to load certificate.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load certificate.';
      });
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(
      text: 'Certificate ID: ${widget.certificateId}',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Certificate ID copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificate'),
        actions: [
          if (_cert != null)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share',
              onPressed: _copyLink,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: cs.error),
                    ),
                  ),
                )
              : _CertificateBody(cert: _cert!),
    );
  }
}

class _CertificateBody extends StatelessWidget {
  const _CertificateBody({required this.cert});

  final ExamCertificate cert;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scorePct = cert.scorePct.toStringAsFixed(0);
    final issued = DateTime.tryParse(cert.issuedAt);
    final issuedLabel = issued != null
        ? '${issued.year}-${issued.month.toString().padLeft(2, '0')}-${issued.day.toString().padLeft(2, '0')}'
        : cert.issuedAt;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.workspace_premium, size: 64, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            'Certificate of Completion',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _Row(label: 'Topic', value: _capitalise(cert.topic)),
          _Row(label: 'Language', value: cert.language.toUpperCase()),
          _Row(label: 'Score', value: '$scorePct%'),
          _Row(label: 'Issued', value: issuedLabel),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              cert.disclaimer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          SelectableText(
            cert.certificateId,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.outline,
                  fontFamily: 'monospace',
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.outline)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
