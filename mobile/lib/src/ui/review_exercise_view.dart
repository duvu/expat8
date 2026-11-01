import 'package:flutter/material.dart';

import '../review/review_exercise.dart';
import '../theme/app_theme.dart';
import '../widgets/study_card_frame.dart';
import '../theme/app_radius.dart';

/// What the learner did with a review exercise.
class ReviewAnswer {
  const ReviewAnswer({
    required this.correct,
    required this.elapsed,
    this.nearMiss = false,
  });

  final bool correct;
  final Duration elapsed;
  final bool nearMiss;
}

/// An active-recall review card: the learner answers and sees whether it was
/// right (and the word with its meaning). Moving on is the host screen's
/// pinned Continue button, so it is always within reach however tall the card.
class ReviewExerciseView extends StatefulWidget {
  const ReviewExerciseView({
    required this.exercise,
    required this.onAnswered,
    this.onListen,
    super.key,
  });

  final ReviewExercise exercise;
  final Future<void> Function(ReviewAnswer answer) onAnswered;

  /// Speaks the word; required for [ReviewExerciseKind.listen].
  final Future<void> Function(String term)? onListen;

  @override
  State<ReviewExerciseView> createState() => _ReviewExerciseViewState();
}

class _ReviewExerciseViewState extends State<ReviewExerciseView> {
  final _stopwatch = Stopwatch()..start();
  final _typed = TextEditingController();
  final _feedbackKey = GlobalKey();
  String? _picked;
  ReviewAnswer? _answer;

  ReviewExercise get _exercise => widget.exercise;

  @override
  void initState() {
    super.initState();
    if (_exercise.kind == ReviewExerciseKind.listen) _listen();
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _listen() =>
      widget.onListen?.call(_exercise.word.term).catchError((Object _) {});

  Future<void> _submit(ReviewAnswer answer) async {
    if (_answer != null) return;
    _stopwatch.stop();
    setState(() => _answer = answer);
    // The feedback appears below the choices: bring it on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _feedbackKey.currentContext;
      if (context != null && context.mounted) {
        Scrollable.ensureVisible(context,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      }
    });
    await widget.onAnswered(answer);
  }

  void _choose(String choice) {
    _picked = choice;
    _submit(ReviewAnswer(
        correct: choice == _exercise.answer, elapsed: _stopwatch.elapsed));
  }

  void _checkTyped() {
    if (_typed.text.trim().isEmpty) return;
    final result = checkTypedAnswer(_typed.text, _exercise.answer);
    _submit(ReviewAnswer(
      correct: result != TypedAnswer.wrong,
      nearMiss: result == TypedAnswer.nearMiss,
      elapsed: _stopwatch.elapsed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = _exercise.word;
    return StudyCardFrame(
      level: word.difficulty,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_kindIcon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_kindLabel,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.primary)),
                ),
                if (word.difficulty.trim().isNotEmpty)
                  LevelBadge(level: word.difficulty),
              ],
            ),
            const SizedBox(height: 16),
            _prompt(theme),
            const SizedBox(height: 20),
            if (_exercise.kind == ReviewExerciseKind.typeWord)
              _typeField(theme)
            else
              for (final (i, choice) in _exercise.choices.indexed)
                _ChoiceButton(
                  key: ValueKey('review-choice-$i'),
                  label: choice,
                  state: _choiceState(choice),
                  onPressed: _answer == null ? () => _choose(choice) : null,
                ),
            if (_answer case final answer?) ...[
              const SizedBox(height: 16),
              _Feedback(key: _feedbackKey, answer: answer, exercise: _exercise),
            ],
          ],
        ),
      ),
    );
  }

  Widget _prompt(ThemeData theme) {
    final word = _exercise.word;
    final muted = theme.textTheme.bodyMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return switch (_exercise.kind) {
      ReviewExerciseKind.chooseMeaning => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child:
                        Text(word.term, style: theme.textTheme.displaySmall)),
                if (widget.onListen != null)
                  IconButton.filledTonal(
                    tooltip: 'Listen',
                    onPressed: _listen,
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
              ],
            ),
            if (word.ipa.trim().isNotEmpty) Text(word.ipa, style: muted),
          ],
        ),
      ReviewExerciseKind.listen => Center(
          child: IconButton.filled(
            key: const ValueKey('review-listen'),
            iconSize: 40,
            padding: const EdgeInsets.all(20),
            tooltip: 'Play again',
            onPressed: _listen,
            icon: const Icon(Icons.volume_up_rounded),
          ),
        ),
      ReviewExerciseKind.fillBlank => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_exercise.blankedExample!,
                style: theme.textTheme.titleLarge?.copyWith(height: 1.4)),
            if (word.exampleVi.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(word.exampleVi, style: muted),
            ],
          ],
        ),
      ReviewExerciseKind.typeWord => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(word.meaningVi, style: theme.textTheme.headlineSmall),
            if (_exercise.blankedExample case final example?) ...[
              const SizedBox(height: 8),
              Text(example, style: muted),
            ],
          ],
        ),
    };
  }

  Widget _typeField(ThemeData theme) => Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('review-type-field'),
              controller: _typed,
              enabled: _answer == null,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _checkTyped(),
              decoration: const InputDecoration(
                hintText: 'Type the word',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const ValueKey('review-check'),
            onPressed: _answer == null ? _checkTyped : null,
            child: const Text('Check'),
          ),
        ],
      );

  _ChoiceState _choiceState(String choice) {
    if (_answer == null) return _ChoiceState.idle;
    if (choice == _exercise.answer) return _ChoiceState.right;
    return choice == _picked ? _ChoiceState.wrong : _ChoiceState.idle;
  }

  String get _kindLabel => switch (_exercise.kind) {
        ReviewExerciseKind.chooseMeaning => 'Review · choose the meaning',
        ReviewExerciseKind.listen => 'Review · listen and choose',
        ReviewExerciseKind.fillBlank => 'Review · fill in the blank',
        ReviewExerciseKind.typeWord => 'Review · type the word',
      };

  IconData get _kindIcon => switch (_exercise.kind) {
        ReviewExerciseKind.chooseMeaning => Icons.quiz_outlined,
        ReviewExerciseKind.listen => Icons.hearing_rounded,
        ReviewExerciseKind.fillBlank => Icons.short_text_rounded,
        ReviewExerciseKind.typeWord => Icons.keyboard_rounded,
      };
}

enum _ChoiceState { idle, right, wrong }

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.state,
    required this.onPressed,
    super.key,
  });

  final String label;
  final _ChoiceState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = switch (state) {
      _ChoiceState.right => colors.statusSuccess,
      _ChoiceState.wrong => colors.statusError,
      _ChoiceState.idle => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          side: accent == null ? null : BorderSide(color: accent, width: 2),
          backgroundColor: accent?.withValues(alpha: 0.12),
          disabledForegroundColor: accent ??
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            if (accent != null)
              Icon(
                  state == _ChoiceState.right
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: accent),
          ],
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.answer, required this.exercise, super.key});

  final ReviewAnswer answer;
  final ReviewExercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final color = answer.correct ? colors.statusSuccess : colors.statusError;
    final word = exercise.word;
    final title = !answer.correct
        ? 'Not quite — it will come back soon'
        : answer.nearMiss
            ? 'Almost! Check the spelling'
            : 'Correct!';
    return Container(
      key: const ValueKey('review-feedback'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.control,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleMedium?.copyWith(color: color)),
          const SizedBox(height: 6),
          Text('${word.term} — ${word.meaningVi}',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (word.example.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(word.example,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
