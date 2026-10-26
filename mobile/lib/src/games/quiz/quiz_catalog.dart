import 'package:flutter/material.dart';

import '../english/english_quiz.dart';
import '../english/sentence_builder.dart';
import '../math/math_problem.dart';
import '../math/math_race.dart';
import '../math/number_tower.dart';
import 'blaster_game.dart';
import 'duel_game.dart';
import 'quiz_game_context.dart';
import 'quiz_screens.dart';
import 'whack_game.dart';

/// How a quiz game presents itself (hub card and home screen).
class QuizGameInfo {
  const QuizGameInfo({
    required this.description,
    required this.tagline,
    required this.howTo,
    required this.icon,
    required this.colors,
    required this.play,
  });

  final String description;
  final String tagline;
  final List<String> howTo;
  final IconData icon;
  final List<Color> colors;
  final QuizPlayBuilder play;
}

/// The single source of truth for every quiz game's copy, look and screen.
QuizGameInfo quizGameInfo(QuizGameKind kind) => switch (kind) {
      QuizGameKind.blaster => QuizGameInfo(
          description: 'Solve the falling problems before they land.',
          tagline:
              'Problems fall from the sky. Solve the lowest one before it lands!',
          howTo: const [
            'The outlined problem is the next to solve: tap its answer below.',
            'Faster answers score more points; streaks add a bonus.',
            'A wrong answer pushes the problem down. If it lands you lose a heart.',
            'More problems fall, and faster, as you get them right.',
          ],
          icon: Icons.rocket_launch_rounded,
          colors: const [Color(0xFF0B1026), Color(0xFF4338CA)],
          play: (ctx, level, theme) => BlasterScreen(
              context: ctx, game: kind, level: level, theme: theme),
        ),
      QuizGameKind.race => QuizGameInfo(
          description: 'Type the answers to drive your car to the finish.',
          tagline: 'Type the answer to drive your car. Beat the two racers!',
          howTo: const [
            'Work out each problem and type the result (± for negatives).',
            'Every correct answer moves your car; quick answers move it further.',
            'Three quick answers in a row fire a NITRO boost.',
            'The other cars never stop: compute fast and carefully to win.',
          ],
          icon: Icons.directions_car_filled_rounded,
          colors: const [Color(0xFFB91C1C), Color(0xFFF59E0B)],
          play: (ctx, level, theme) => MathRaceScreen(
              context: ctx, level: level as MathLevel, theme: theme),
        ),
      QuizGameKind.moles => QuizGameInfo(
          description: 'Whack the mole holding the right answer.',
          tagline: 'Work out the answer, then whack it before it hides!',
          howTo: const [
            'Solve the problem at the top in your head.',
            'Whack the one holding the answer before it ducks back down.',
            'A wrong whack costs 2 seconds. You have 60 seconds.',
            'Keep a streak going: they pop up for less and less time.',
          ],
          icon: Icons.sports_handball_rounded,
          colors: const [Color(0xFF15803D), Color(0xFF65A30D)],
          play: (ctx, level, theme) =>
              WhackScreen(context: ctx, game: kind, level: level, theme: theme),
        ),
      QuizGameKind.tower => QuizGameInfo(
          description: 'Pick blocks that make the target number.',
          tagline:
              'Pick blocks that make the target before the tower reaches the top!',
          howTo: const [
            'Grades 1, 2 and 4: tap blocks that ADD UP to the target.',
            'Grades 3 and 5–9: tap TWO blocks that make the target (× or ±).',
            'A wrong pick clears your selection.',
            'Blocks keep dropping in. If the tower fills up, the game ends.',
          ],
          icon: Icons.view_column_rounded,
          colors: const [Color(0xFF7C3AED), Color(0xFFDB2777)],
          play: (ctx, level, theme) => NumberTowerScreen(
              context: ctx, level: level as MathLevel, theme: theme),
        ),
      QuizGameKind.duel => _duel(
          kind, 'Two players, one phone. First to 10 correct answers wins!'),
      QuizGameKind.grammarBlaster => QuizGameInfo(
          description: 'Grammar sentences fall: pick the right word fast.',
          tagline:
              'Sentences fall from the sky. Fill the blank before they land!',
          howTo: const [
            'The outlined token is next: read its sentence below the field.',
            'Tap the word or phrase that correctly fills the blank.',
            'A wrong answer pushes it down. If it lands you lose a heart.',
            'Missed sentences come back later with the grammar rule.',
          ],
          icon: Icons.menu_book_rounded,
          colors: const [Color(0xFF0E7490), Color(0xFF4338CA)],
          play: (ctx, level, theme) => BlasterScreen(
              context: ctx, game: kind, level: level, theme: theme),
        ),
      QuizGameKind.wordWhack => QuizGameInfo(
          description: 'Whack the word that completes the sentence.',
          tagline: 'Read the sentence, then whack the word that fits!',
          howTo: const [
            'Read the sentence at the top: one word or phrase is missing.',
            'Whack the one holding the right answer before it hides.',
            'A wrong whack costs 2 seconds. You have 60 seconds.',
          ],
          icon: Icons.spellcheck_rounded,
          colors: const [Color(0xFF047857), Color(0xFF0E7490)],
          play: (ctx, level, theme) =>
              WhackScreen(context: ctx, game: kind, level: level, theme: theme),
        ),
      QuizGameKind.englishDuel =>
        _duel(kind, 'Two players, one phone. First to 10 grammar points wins!'),
      QuizGameKind.sentenceBuilder => QuizGameInfo(
          description: 'Tap the words in the right order to build sentences.',
          tagline:
              'Put the words in the right order. Build as many sentences as you can!',
          howTo: const [
            'Tap the word chips in order to build a correct sentence.',
            'A wrong word counts as a mistake and shows the grammar tip.',
            'Sentences with no mistakes score full points. 90 seconds.',
          ],
          icon: Icons.segment_rounded,
          colors: const [Color(0xFF9333EA), Color(0xFF0EA5E9)],
          play: (ctx, level, theme) => SentenceBuilderScreen(
              context: ctx, level: level as EnglishLevel, theme: theme),
        ),
    };

QuizGameInfo _duel(QuizGameKind kind, String tagline) => QuizGameInfo(
      description: 'Two players on one phone, first to 10 wins.',
      tagline: tagline,
      howTo: const [
        'Sit facing each other with the phone flat between you.',
        "The level above is Player 1's; Player 2 picks theirs before the start, so a parent can play a child fairly.",
        'Tap the right answer on your side to score and get the next question.',
        'A wrong tap freezes you for 1.5 seconds, so think before you tap!',
      ],
      icon: Icons.people_alt_rounded,
      colors: const [Color(0xFF0369A1), Color(0xFFDB2777)],
      play: (ctx, level, theme) =>
          DuelScreen(context: ctx, game: kind, level: level, theme: theme),
    );

/// The home screen of [kind].
QuizGameHomeScreen quizGameHome(QuizGameContext context, QuizGameKind kind) {
  final info = quizGameInfo(kind);
  return QuizGameHomeScreen(
    context: context,
    game: kind,
    tagline: info.tagline,
    howTo: info.howTo,
    icon: info.icon,
    colors: info.colors,
    play: info.play,
  );
}
