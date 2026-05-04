import 'package:flutter/material.dart';

import '../models/study_event.dart';
import '../session/learning_session_controller.dart';
import 'vocabulary_card.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({required this.controller, super.key});

  final LearningSessionController controller;

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.loadInitial();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary')),
      body: RefreshIndicator(
        onRefresh: controller.nextCard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 24),
            if (controller.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (controller.currentWord != null)
              VocabularyCardView(word: controller.currentWord!)
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(controller.statusMessage ?? 'No card loaded.'),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _RatingButton(
                    label: 'Not remembered',
                    onPressed: () => controller.rateCurrent(StudyRating.notRemembered),
                  ),
                  _RatingButton(
                    label: 'Hard',
                    onPressed: () => controller.rateCurrent(StudyRating.hard),
                  ),
                  _RatingButton(
                    label: 'Remembered',
                    onPressed: () => controller.rateCurrent(StudyRating.remembered),
                  ),
                  _RatingButton(
                    label: 'Too easy',
                    onPressed: () => controller.rateCurrent(StudyRating.tooEasy),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onPressed, child: Text(label));
  }
}
