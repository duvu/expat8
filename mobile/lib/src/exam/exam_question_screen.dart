import 'package:flutter/material.dart';

import '../models/user_session.dart';
import 'exam_results_screen.dart';
import 'exam_session_controller.dart';

/// Displays exam questions one at a time (MCQ).
///
/// Tapping a choice commits the answer immediately and advances to the next
/// question. After the last question the session is submitted and the
/// [ExamResultsScreen] is shown.
class ExamQuestionScreen extends StatefulWidget {
  const ExamQuestionScreen({
    required this.controller,
    required this.userSession,
    super.key,
  });

  final ExamSessionController controller;
  final UserSession userSession;

  @override
  State<ExamQuestionScreen> createState() => _ExamQuestionScreenState();
}

class _ExamQuestionScreenState extends State<ExamQuestionScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (widget.controller.state == ExamState.results) {
      // Replace the question screen with results.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ExamResultsScreen(
            controller: widget.controller,
            userSession: widget.userSession,
          ),
        ),
      );
      return;
    }
    setState(() {});
    final err = widget.controller.errorMessage;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final question = ctrl.currentQuestion;
    final answered = ctrl.currentAnswer;
    final total = ctrl.totalQuestions;
    final current = ctrl.currentQuestionIndex + 1;
    final isSubmitting = ctrl.state == ExamState.submitting;

    if (question == null || isSubmitting) {
      // Block system back during submission so the route stays mounted and
      // _onControllerChanged() can navigate to ExamResultsScreen once the
      // response arrives.
      return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(title: const Text('Exam')),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Question $current of $total'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (current - 1) / total,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 24),

            // Prompt
            if (question.questionType == 'sentence_context' &&
                question.sentence != null &&
                question.highlight != null) ...[
              _SentenceContextPrompt(
                sentence: question.sentence!,
                highlight: question.highlight!,
              ),
            ] else ...[
              Center(
                child: Text(
                  question.promptWord,
                  style: Theme.of(context).textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'What is the meaning?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Choices
            ...question.choices.asMap().entries.map((entry) {
              final idx = entry.key;
              final choice = entry.value;
              final isSelected = answered?.selectedChoice == idx;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChoiceTile(
                  label: choice,
                  isSelected: isSelected,
                  isAnswered: answered != null,
                  onTap: answered == null
                      ? () async {
                          await ctrl.submitAnswerAndAdvance(
                            userSession: widget.userSession,
                            choiceIndex: idx,
                          );
                          if (mounted) {
                            setState(() {});
                          }
                        }
                      : null,
                ),
              );
            }),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Displays the sentence for a `sentence_context` question, with [highlight]
/// shown in bold to draw the learner's attention.
class _SentenceContextPrompt extends StatelessWidget {
  const _SentenceContextPrompt({
    required this.sentence,
    required this.highlight,
  });

  final String sentence;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final parts = sentence.split(highlight);
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: parts[i]));
      }
      if (i < parts.length - 1) {
        spans.add(TextSpan(
          text: highlight,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: textTheme.bodyLarge,
            children: spans,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'What does the highlighted phrase mean?',
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.isSelected,
    required this.isAnswered,
    this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isAnswered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color? bgColor = isSelected ? cs.primaryContainer : null;
    final Color? borderColor = isSelected ? cs.primary : cs.outline;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: borderColor ?? cs.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isSelected ? cs.onPrimaryContainer : null,
              ),
        ),
      ),
    );
  }
}
