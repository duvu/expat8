import 'dart:async';

import 'package:flutter/material.dart';

import '../api/backend_api_client.dart';
import '../models/user_session.dart';
import 'exam_certificate_screen.dart';
import 'exam_session_controller.dart';

/// Results screen shown after exam submission.
///
/// Displays score, pass/fail status, and a certificate banner if the user
/// passed (≥ 70%). Provides "View Certificate", "Take Again", and "Done"
/// actions.
///
/// Reactively listens to [controller] via [ListenableBuilder] so it rebuilds
/// whenever the result or state changes, eliminating any permanent-spinner
/// scenario where [controller.result] was null at the moment of the first
/// build. A 20-second wall-clock timeout is enforced via a [Timer] started in
/// [initState]; if the result has not arrived by then, an error UI with a
/// "Try Again" button is shown instead.
class ExamResultsScreen extends StatefulWidget {
  const ExamResultsScreen({
    required this.controller,
    required this.userSession,
    super.key,
  });

  final ExamSessionController controller;
  final UserSession userSession;

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  /// Set to true when the 20-second timeout fires without a result arriving.
  bool _timedOut = false;

  /// Defensive timeout — cancelled as soon as [controller.result] is set.
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 20), () {
      if (widget.controller.result == null && mounted) {
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  // ─── actions ─────────────────────────────────────────────────────────────

  void _onRetry() {
    _timeoutTimer?.cancel();
    widget.controller.reset();
    Navigator.of(context).pop();
  }

  // ─── error UI helper ─────────────────────────────────────────────────────

  Widget _buildErrorUI(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _onRetry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final result = controller.result;

        // Cancel the timeout timer early if the result has already arrived —
        // avoids a spurious setState after success.
        if (result != null && _timeoutTimer?.isActive == true) {
          _timeoutTimer!.cancel();
        }

        // Priority 1: result available — show the full results UI.
        if (result != null) {
          return _buildResultsScaffold(context, result);
        }

        // Priority 2: 20-second timeout expired without a result.
        if (_timedOut) {
          return Scaffold(
            appBar: AppBar(title: const Text('Results')),
            body: _buildErrorUI(
                'Exam submission timed out. Please try again.'),
          );
        }

        // Priority 3: submission failed — controller reverted to active state
        // with a non-null errorMessage.
        if (controller.state == ExamState.active &&
            controller.errorMessage != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Results')),
            body: _buildErrorUI(controller.errorMessage!),
          );
        }

        // Priority 4: genuinely waiting for the result.
        return Scaffold(
          appBar: AppBar(title: const Text('Results')),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  // ─── results scaffold (happy path) ───────────────────────────────────────

  Widget _buildResultsScaffold(
      BuildContext context, ExamSubmitResponse result) {
    final passed = result.passed;
    final scorePct = result.scorePct.toStringAsFixed(0);
    final certId = result.certificateId;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Results'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Score circle
            _ScoreCircle(scorePct: result.scorePct, passed: passed),
            const SizedBox(height: 24),

            Text(
              passed ? 'You passed!' : 'Keep practising!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: passed ? cs.primary : cs.error,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${result.correctCount} / ${result.totalQuestions} correct  •  $scorePct%',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Language: ${result.language.toUpperCase()}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.outline,
                  ),
              textAlign: TextAlign.center,
            ),

            if (passed && certId != null) ...[
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.workspace_premium,
                        size: 40, color: cs.primary),
                    const SizedBox(height: 8),
                    Text(
                      'Certificate Earned!',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ExamCertificateScreen(certificateId: certId),
                        ),
                      ),
                      child: const Text('View Certificate'),
                    ),
                  ],
                ),
              ),
            ],

            if (!passed) ...[
              const SizedBox(height: 24),
              Text(
                'You need 70% to pass. Review your vocabulary and try again!',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.outline),
                textAlign: TextAlign.center,
              ),
            ],

            const Spacer(),

            // Actions
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  widget.controller.reset();
                  // Pop back to the learning screen.
                  Navigator.of(context).pop();
                },
                child: const Text('Take Again'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.controller.reset();
                  // Single pop — the question route was replaced by results,
                  // so only one pop is needed to return to the learning screen.
                  Navigator.of(context).pop();
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── score circle widget ──────────────────────────────────────────────────────

class _ScoreCircle extends StatelessWidget {
  const _ScoreCircle({required this.scorePct, required this.passed});

  final double scorePct;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: scorePct / 100,
              strokeWidth: 10,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                  passed ? cs.primary : cs.error),
            ),
          ),
          Text(
            '${scorePct.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: passed ? cs.primary : cs.error,
                ),
          ),
        ],
      ),
    );
  }
}
