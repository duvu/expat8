import 'dart:convert';
import 'dart:io';

import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/srs/srs_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

StudyRating _rating(String api) =>
    StudyRating.values.firstWhere((r) => r.apiValue == api);

void main() {
  // Shared with backend/test/srs.test.js: the app schedules offline exactly
  // like the server will after sync.
  final vectors =
      jsonDecode(File('../contracts/srs_vectors.json').readAsStringSync())
          as Map<String, dynamic>;

  test('matches every shared SRS vector', () {
    for (final c in (vectors['cases'] as List).cast<Map<String, dynamic>>()) {
      var memory = const SrsMemory();
      for (final step in (c['steps'] as List).cast<Map<String, dynamic>>()) {
        final api = step['rating'] as String;
        // The server ignores unknown ratings; the app never produces them.
        if (StudyRating.values.any((r) => r.apiValue == api)) {
          memory = memory.rate(_rating(api));
        }
        final ratedAt = DateTime.parse(step['rated_at'] as String);
        final reason = '${c['name']} after $api at ${step['rated_at']}';
        expect(memory.reps, step['reps'], reason: reason);
        expect(memory.lapses, step['lapses'], reason: reason);
        expect(memory.ease, (step['ease'] as num).toDouble(), reason: reason);
        expect(memory.intervalDays, (step['interval_days'] as num).toDouble(),
            reason: reason);
        expect(
            memory.status.name,
            switch (step['status']) {
              'learning' => WordStatus.learning.name,
              'review' => WordStatus.review.name,
              _ => WordStatus.mastered.name,
            },
            reason: reason);
        expect(
            memory.dueAfter(ratedAt).toUtc().toIso8601String(), step['due_at'],
            reason: reason);
      }
    }
  });

  test('a forgotten word comes back within minutes, a known one in days', () {
    final at = DateTime.utc(2026, 1, 1, 8);
    final forgotten = const SrsMemory().rate(StudyRating.tooHard);
    expect(forgotten.dueAfter(at), at.add(const Duration(minutes: 10)));
    expect(forgotten.status, WordStatus.learning);
    final known = const SrsMemory().rate(StudyRating.easy);
    expect(known.dueAfter(at), at.add(const Duration(days: 2)));
    expect(known.status, WordStatus.review);
  });
}
