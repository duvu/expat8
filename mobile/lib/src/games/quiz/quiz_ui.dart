import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../common/game_story.dart';
import '../common/game_story_scene.dart';
import '../common/game_theme.dart';

/// Colours for a math game scene: the chapter's sky and accent, with panels
/// and text that stay readable on it.
class QuizPalette {
  const QuizPalette._({
    required this.skyTop,
    required this.skyBottom,
    required this.ground,
    required this.text,
    required this.panel,
    required this.onPanel,
    required this.accent,
    required this.good,
    required this.bad,
  });

  factory QuizPalette.of(GameVisualTheme theme,
      {GameStoryChapter chapter = GameStoryChapter.one}) {
    final stage = GameStory.stage(theme, chapter);
    final dark = stage.dark;
    return QuizPalette._(
      skyTop: stage.skyTop,
      skyBottom: stage.skyBottom,
      ground: stage.horizon,
      text: dark ? Colors.white : const Color(0xFF3B2A7A),
      panel: dark ? const Color(0xE61A2342) : Colors.white,
      onPanel: dark ? Colors.white : const Color(0xFF3B2A7A),
      accent: stage.accent,
      good: dark ? const Color(0xFF4ADE80) : const Color(0xFF22A06B),
      bad: dark ? const Color(0xFFFF5C7A) : const Color(0xFFE5484D),
    );
  }

  final Color skyTop;
  final Color skyBottom;
  final Color ground;
  final Color text;
  final Color panel;
  final Color onPanel;
  final Color accent;
  final Color good;
  final Color bad;
}

/// The chapter's scenery behind a math game, plus the level-up banner when a
/// chapter opens. The scenery is static and cached by its repaint boundary;
/// moving pieces live in separate layers on top.
class QuizBackdrop extends StatelessWidget {
  const QuizBackdrop({
    required this.theme,
    required this.child,
    this.chapter = GameStoryChapter.one,
    super.key,
  });

  final GameVisualTheme theme;
  final GameStoryChapter chapter;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
              child: CustomPaint(painter: StoryScenePainter(theme, chapter))),
          child,
          // Keyed by chapter: plays once each time a chapter opens.
          StoryLevelUpBanner(
              key: ValueKey('banner-${chapter.name}'),
              theme: theme,
              chapter: chapter),
        ],
      );
}

/// A falling/popping piece carrying a number or a problem: a rock in space,
/// a patterned egg at Easter. Wrapped in a repaint boundary so moving it does
/// not repaint it.
class QuizToken extends StatelessWidget {
  const QuizToken({
    required this.theme,
    required this.label,
    required this.width,
    this.seed = 0,
    this.highlight = false,
    this.fontSize,
    super.key,
  });

  final GameVisualTheme theme;
  final String label;
  final double width;
  final int seed;

  /// Outlined in the accent colour (e.g. the problem to answer next).
  final bool highlight;
  final double? fontSize;

  double get height =>
      theme == GameVisualTheme.easter ? width * 1.2 : width * 0.72;

  @override
  Widget build(BuildContext context) {
    final palette = QuizPalette.of(theme);
    final easter = theme == GameVisualTheme.easter;
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter:
              _TokenPainter(theme, seed, highlight ? palette.accent : null),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(top: easter ? height * 0.08 : 0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: easter
                        ? Colors.white.withValues(alpha: 0.88)
                        : const Color(0x730B1026),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: fontSize ?? width * 0.2,
                      fontWeight: FontWeight.w800,
                      color: easter ? palette.text : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TokenPainter extends CustomPainter {
  _TokenPainter(this.theme, this.seed, this.outline);

  final GameVisualTheme theme;
  final int seed;
  final Color? outline;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (theme == GameVisualTheme.easter) {
      _paintEgg(canvas, rect);
    } else {
      _paintRock(canvas, rect);
    }
  }

  void _paintEgg(Canvas canvas, Rect rect) {
    final base = easterEggColors[seed % easterEggColors.length];
    final hsl = HSLColor.fromColor(base);
    final deep =
        hsl.withLightness((hsl.lightness - 0.22).clamp(0.2, 0.8)).toColor();
    final path = eggPath(rect);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(base, Colors.white, 0.35)!, base],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipPath(path);
    final white = Paint()..color = Colors.white.withValues(alpha: 0.85);
    switch (seed % 3) {
      case 0:
        canvas.drawRect(
            Rect.fromLTWH(
                rect.left, rect.height * 0.72, rect.width, rect.height * 0.08),
            Paint()..color = deep.withValues(alpha: 0.75));
      case 1:
        for (var i = 0; i < 5; i++) {
          canvas.drawCircle(
              Offset(rect.width * (0.2 + i * 0.15),
                  rect.height * (i.isEven ? 0.2 : 0.85)),
              rect.width * 0.045,
              white);
        }
      default:
        final zig = Path()..moveTo(0, rect.height * 0.78);
        for (var i = 0; i < 6; i++) {
          zig
            ..lineTo(rect.width * (i + 0.5) / 6,
                rect.height * (i.isEven ? 0.84 : 0.72))
            ..lineTo(rect.width * (i + 1) / 6, rect.height * 0.78);
        }
        canvas.drawPath(
            zig,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = rect.height * 0.04
              ..color = deep);
    }
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outline == null ? 2 : 4
        ..color = outline ?? deep,
    );
  }

  void _paintRock(Canvas canvas, Rect rect) {
    final random = Random(seed);
    final path = Path();
    for (var i = 0; i < 11; i++) {
      final a = i / 11 * pi * 2;
      final r = 0.86 + random.nextDouble() * 0.14;
      final p = Offset(rect.center.dx + cos(a) * r * rect.width / 2,
          rect.center.dy + sin(a) * r * rect.height / 2);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C87A6), Color(0xFF5A6480), Color(0xFF3E4660)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outline == null ? 2 : 4
        ..color = outline ?? const Color(0xFF9FA8C9),
    );
  }

  @override
  bool shouldRepaint(_TokenPainter old) =>
      old.theme != theme || old.seed != seed || old.outline != outline;
}

/// Egg outline used by the Easter skin.
Path eggPath(Rect rect) {
  final cx = rect.center.dx, w = rect.width, h = rect.height;
  final top = rect.top, bottom = rect.bottom;
  return Path()
    ..moveTo(cx, top)
    ..cubicTo(cx + 0.30 * w, top, cx + 0.5 * w, top + 0.30 * h, cx + 0.5 * w,
        top + 0.62 * h)
    ..cubicTo(cx + 0.5 * w, top + 0.85 * h, cx + 0.28 * w, bottom, cx, bottom)
    ..cubicTo(cx - 0.28 * w, bottom, cx - 0.5 * w, top + 0.85 * h, cx - 0.5 * w,
        top + 0.62 * h)
    ..cubicTo(cx - 0.5 * w, top + 0.30 * h, cx - 0.30 * w, top, cx, top)
    ..close();
}

/// Big multiple-choice answer buttons.
class QuizChoiceButtons extends StatelessWidget {
  const QuizChoiceButtons({
    required this.theme,
    this.chapter = GameStoryChapter.one,
    required this.choices,
    required this.onPick,
    this.enabled = true,
    this.keyPrefix = 'math-choice',
    super.key,
  });

  final GameVisualTheme theme;
  final GameStoryChapter chapter;
  final List<String> choices;
  final ValueChanged<String> onPick;
  final bool enabled;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final palette = QuizPalette.of(theme, chapter: chapter);
    final easter = !GameStory.stage(theme, chapter).dark;
    return Row(
      children: [
        for (var i = 0; i < choices.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: SizedBox(
                height: 60,
                child: FilledButton(
                  key: ValueKey('$keyPrefix-${choices[i]}'),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: easter
                        ? easterEggColors[i % easterEggColors.length]
                        : palette.panel,
                    foregroundColor: easter ? palette.text : Colors.white,
                    side: BorderSide(
                        color: easter ? Colors.white : palette.accent,
                        width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: enabled ? () => onPick(choices[i]) : null,
                  child: FittedBox(
                    child: Text(
                      choices[i],
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Number pad for typed answers (computing the exact result, not picking it).
class MathKeypad extends StatelessWidget {
  const MathKeypad({
    required this.theme,
    this.chapter = GameStoryChapter.one,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    required this.onToggleSign,
    super.key,
  });

  final GameVisualTheme theme;
  final GameStoryChapter chapter;
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  /// Toggles a minus sign (negative answers from grade 7).
  final VoidCallback onToggleSign;

  @override
  Widget build(BuildContext context) {
    final palette = QuizPalette.of(theme, chapter: chapter);
    Widget key(String label, VoidCallback onTap, {Color? color, Key? k}) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                key: k,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: color ?? palette.panel,
                  foregroundColor:
                      color == null ? palette.onPanel : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: onTap,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        );
    Widget row(List<int> digits) => Row(children: [
          for (final d in digits)
            key('$d', () => onDigit(d), k: ValueKey('math-key-$d')),
        ]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([7, 8, 9]),
        row([4, 5, 6]),
        row([1, 2, 3]),
        Row(children: [
          key('±', onToggleSign, k: const ValueKey('math-key-sign')),
          key('0', () => onDigit(0), k: const ValueKey('math-key-0')),
          key('⌫', onBackspace,
              color: palette.bad, k: const ValueKey('math-key-back')),
          key('OK', onSubmit,
              color: palette.good, k: const ValueKey('math-key-ok')),
        ]),
      ],
    );
  }
}

/// Score/lives/time strip at the top of a game.
class QuizHud extends StatelessWidget {
  const QuizHud({
    required this.theme,
    this.chapter = GameStoryChapter.one,
    required this.score,
    required this.onPause,
    this.lives,
    this.secondsLeft,
    this.combo = 0,
    this.extra,
    super.key,
  });

  final GameVisualTheme theme;
  final GameStoryChapter chapter;
  final int score;
  final VoidCallback onPause;
  final int? lives;
  final int? secondsLeft;
  final int combo;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final palette = QuizPalette.of(theme, chapter: chapter);
    final style = TextStyle(
        color: palette.text, fontWeight: FontWeight.w800, fontSize: 18);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          if (lives != null)
            for (var i = 0; i < lives!; i++)
              Icon(Icons.favorite, color: palette.bad, size: 22),
          if (secondsLeft != null) ...[
            Icon(Icons.timer_outlined, color: palette.text, size: 20),
            const SizedBox(width: 4),
            Text('${secondsLeft}s',
                key: const ValueKey('math-time-left'), style: style),
          ],
          const SizedBox(width: 8),
          Flexible(child: GameStoryBadge(theme: theme, chapter: chapter)),
          const Spacer(),
          if (extra != null) ...[
            Text(extra!, style: style.copyWith(fontSize: 15)),
            const SizedBox(width: 10),
          ],
          if (combo > 1) ...[
            Text('x$combo',
                style: style.copyWith(color: palette.accent, fontSize: 16)),
            const SizedBox(width: 10),
          ],
          Text('$score', key: const ValueKey('math-score'), style: style),
          IconButton(
            tooltip: 'Pause',
            onPressed: onPause,
            icon: Icon(Icons.pause_circle_outline, color: palette.text),
          ),
        ],
      ),
    );
  }
}

/// Frame loop on a [TickerProvider]; calls [onTick] with seconds since the
/// previous frame (clamped so a resume does not teleport anything).
class GameLoop {
  GameLoop(TickerProvider vsync, this.onTick) {
    _ticker = vsync.createTicker(_handle);
  }

  final void Function(double dt) onTick;
  late final Ticker _ticker;
  Duration? _last;

  bool get isRunning => _ticker.isActive;

  void start() {
    if (_ticker.isActive) return;
    _last = null;
    _ticker.start();
  }

  void stop() {
    if (_ticker.isActive) _ticker.stop();
  }

  void dispose() => _ticker.dispose();

  void _handle(Duration elapsed) {
    final last = _last;
    _last = elapsed;
    if (last == null) return;
    onTick(min((elapsed - last).inMicroseconds / 1e6, 0.1));
  }
}

/// Standard pause sheet. Returns true when the player chose to quit.
Future<bool> showGamePause(BuildContext context) async {
  final quit = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Paused'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('End game'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Resume'),
        ),
      ],
    ),
  );
  return quit ?? false;
}

/// A question as players read it: large for short math facts, wrapping onto
/// a few lines for sentences.
class QuizPromptText extends StatelessWidget {
  const QuizPromptText(this.text, {required this.color, super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: text.length > 18 ? 22 : 34,
          fontWeight: FontWeight.w900,
          height: 1.25,
        ),
      );
}
