import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/material.dart' show ColorScheme, TextStyle, FontWeight;
import 'package:flutter/painting.dart'
    show TextPainter, TextSpan, TextDirection;

import 'sudoku_game_controller.dart';
import 'sudoku_generator.dart' show peersOf;

/// Colors for the board, derived from the app's Material color scheme so the
/// game follows light/dark mode.
class SudokuBoardPalette {
  SudokuBoardPalette.fromScheme(ColorScheme scheme, {this.fontFamily})
      : frame = scheme.surfaceContainerLowest,
        boxTint = scheme.surfaceContainerLow,
        boxTintAlt = scheme.surfaceContainer,
        peer = scheme.primaryContainer.withValues(alpha: 0.35),
        sameValue = scheme.secondaryContainer,
        selected = scheme.primaryContainer,
        selectionRing = scheme.primary,
        thinLine = scheme.outlineVariant,
        thickLine = scheme.onSurfaceVariant,
        given = scheme.onSurface,
        entry = scheme.primary,
        wrong = scheme.error,
        wrongFlash = scheme.errorContainer,
        note = scheme.onSurfaceVariant,
        glow = scheme.tertiary,
        shadow = scheme.shadow,
        confetti = [
          scheme.primary,
          scheme.secondary,
          scheme.tertiary,
          const Color(0xFFFFC107),
          const Color(0xFFFF7043),
          const Color(0xFF42A5F5),
        ];

  final Color frame;
  final Color boxTint;
  final Color boxTintAlt;
  final Color peer;
  final Color sameValue;
  final Color selected;
  final Color selectionRing;
  final Color thinLine;
  final Color thickLine;
  final Color given;
  final Color entry;
  final Color wrong;
  final Color wrongFlash;
  final Color note;
  final Color glow;
  final Color shadow;
  final List<Color> confetti;

  /// Flame draws on a raw canvas, which does not inherit the app font.
  final String? fontFamily;
}

/// Flame game that renders and animates the Sudoku board. All rules live in
/// [SudokuGameController]; this layer only draws state and plays feedback.
class SudokuBoardGame extends FlameGame {
  SudokuBoardGame({required this.controller, required this.palette});

  final SudokuGameController controller;
  SudokuBoardPalette palette;

  late final BoardComponent board;
  StreamSubscription<SudokuFeedback>? _feedbackSubscription;
  final Random _random = Random();

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    board = BoardComponent();
    await add(board);
    _layout(size);
    _feedbackSubscription = controller.feedback.listen(_onFeedback);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _layout(size);
  }

  void _layout(Vector2 size) {
    final side = min(size.x, size.y);
    board
      ..size = Vector2.all(side)
      ..position = Vector2((size.x - side) / 2, (size.y - side) / 2)
      ..relayout();
  }

  @override
  void onRemove() {
    _feedbackSubscription?.cancel();
    super.onRemove();
  }

  void _onFeedback(SudokuFeedback event) {
    switch (event.kind) {
      case SudokuFeedbackKind.correct:
      case SudokuFeedbackKind.hint:
        final cell = board.cells[event.index!];
        cell.pop();
        _sparkle(cell);
      case SudokuFeedbackKind.wrong:
        board.cells[event.index!].shake();
      case SudokuFeedbackKind.unitCompleted:
        for (var i = 0; i < event.cells.length; i++) {
          board.cells[event.cells[i]].glow(delay: i * 0.045);
        }
      case SudokuFeedbackKind.solved:
        _celebrate();
    }
  }

  void _sparkle(CellComponent cell) {
    final center = board.position + cell.position + cell.size / 2;
    final color = palette.glow;
    add(ParticleSystemComponent(
      position: center,
      particle: Particle.generate(
        count: 10,
        lifespan: 0.45,
        generator: (i) {
          final angle = i / 10 * pi * 2;
          final speed = cell.size.x * (2.2 + _random.nextDouble());
          return AcceleratedParticle(
            speed: Vector2(cos(angle), sin(angle)) * speed,
            acceleration: Vector2(cos(angle), sin(angle)) * -speed * 1.5,
            child: CircleParticle(
              radius: max(1.5, cell.size.x * 0.05),
              paint: Paint()..color = color.withValues(alpha: 0.9),
            ),
          );
        },
      ),
    ));
  }

  void _celebrate() {
    for (var i = 0; i < 81; i++) {
      board.cells[i].glow(delay: ((i ~/ 9) + (i % 9)) * 0.035);
    }
    final origin =
        board.position + Vector2(board.size.x / 2, board.size.y * 0.35);
    final colors = palette.confetti;
    add(ParticleSystemComponent(
      position: origin,
      particle: Particle.generate(
        count: 120,
        lifespan: 2.6,
        generator: (i) {
          final color = colors[i % colors.length];
          final w = board.size.x * (0.012 + _random.nextDouble() * 0.014);
          final h = w * (1.6 + _random.nextDouble());
          final spin = (_random.nextDouble() - 0.5) * 18;
          return AcceleratedParticle(
            speed: Vector2(
              (_random.nextDouble() - 0.5) * board.size.x * 2.4,
              -board.size.y * (0.9 + _random.nextDouble() * 1.3),
            ),
            acceleration: Vector2(0, board.size.y * 2.2),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final fade = 1 - Curves.easeIn.transform(particle.progress);
                canvas
                  ..save()
                  ..rotate(spin * particle.progress);
                canvas.drawRect(
                  Rect.fromCenter(center: Offset.zero, width: w, height: h),
                  Paint()..color = color.withValues(alpha: fade),
                );
                canvas.restore();
              },
            ),
          );
        },
      ),
    ));
  }
}

/// Frame, grid lines and the animated selection ring; owns the 81 cells.
class BoardComponent extends PositionComponent
    with HasGameReference<SudokuBoardGame> {
  final List<CellComponent> cells = [];
  final Vector2 _selectionPos = Vector2.zero();
  bool _selectionPlaced = false;

  double get cellSize => (size.x - _padding * 2) / 9;
  double get _padding => size.x * 0.02;

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < 81; i++) {
      final cell = CellComponent(i);
      cells.add(cell);
      await add(cell);
    }
    // Grid lines and the selection ring render above the cells.
    await add(_BoardOverlay(this));
  }

  void relayout() {
    if (cells.length != 81) return;
    for (final cell in cells) {
      cell
        ..size = Vector2.all(cellSize)
        ..position = _cellOrigin(cell.index);
    }
    _selectionPlaced = false;
  }

  Vector2 _cellOrigin(int index) => Vector2(
        _padding + (index % 9) * cellSize,
        _padding + (index ~/ 9) * cellSize,
      );

  @override
  void update(double dt) {
    super.update(dt);
    final selected = game.controller.selected;
    if (selected == null) return;
    final target = _cellOrigin(selected);
    if (!_selectionPlaced) {
      _selectionPos.setFrom(target);
      _selectionPlaced = true;
    } else {
      // Critically damped glide toward the selected cell.
      final t = 1 - exp(-dt * 22);
      _selectionPos.lerp(target, t);
    }
  }

  @override
  void render(Canvas canvas) {
    final palette = game.palette;
    final radius = Radius.circular(size.x * 0.035);
    final frame = RRect.fromRectAndRadius(size.toRect(), radius);
    canvas.drawShadow(
        Path()..addRRect(frame), palette.shadow, size.x * 0.02, false);
    canvas.drawRRect(frame, Paint()..color = palette.frame);

    // Checkerboard tint for the 3x3 boxes.
    final box = cellSize * 3;
    for (var b = 0; b < 9; b++) {
      final rect = Rect.fromLTWH(
        _padding + (b % 3) * box,
        _padding + (b ~/ 3) * box,
        box,
        box,
      );
      canvas.drawRect(
        rect,
        Paint()..color = b.isEven ? palette.boxTint : palette.boxTintAlt,
      );
    }
  }

  void renderGrid(Canvas canvas) {
    final palette = game.palette;
    final thin = Paint()
      ..color = palette.thinLine
      ..strokeWidth = max(0.5, size.x * 0.0015);
    final thick = Paint()
      ..color = palette.thickLine
      ..strokeWidth = max(1.5, size.x * 0.005)
      ..strokeCap = StrokeCap.round;
    final start = _padding, end = _padding + cellSize * 9;
    for (var i = 1; i < 9; i++) {
      final p = _padding + i * cellSize;
      final paint = i % 3 == 0 ? thick : thin;
      canvas
        ..drawLine(Offset(p, start), Offset(p, end), paint)
        ..drawLine(Offset(start, p), Offset(end, p), paint);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(start, start, end - start, end - start),
        Radius.circular(size.x * 0.012),
      ),
      thick..style = PaintingStyle.stroke,
    );
  }

  void renderSelection(Canvas canvas) {
    if (game.controller.selected == null || !_selectionPlaced) return;
    final inset = cellSize * 0.06;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          _selectionPos.x + inset,
          _selectionPos.y + inset,
          cellSize - inset * 2,
          cellSize - inset * 2,
        ),
        Radius.circular(cellSize * 0.18),
      ),
      Paint()
        ..color = game.palette.selectionRing
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2, cellSize * 0.07),
    );
  }
}

class _BoardOverlay extends Component {
  _BoardOverlay(this.board) : super(priority: 100);

  final BoardComponent board;

  @override
  void render(Canvas canvas) {
    board
      ..renderGrid(canvas)
      ..renderSelection(canvas);
  }
}

/// One cell: background state, digit or notes, and its own feedback tweens.
class CellComponent extends PositionComponent
    with TapCallbacks, HasGameReference<SudokuBoardGame> {
  CellComponent(this.index);

  final int index;

  static const _popDuration = 0.28;
  static const _shakeDuration = 0.42;
  static const _glowDuration = 0.55;

  double _popT = 1;
  double _shakeT = 1;
  double _glowT = 1;
  double _glowDelay = 0;

  final Map<String, TextPainter> _textCache = {};

  void pop() => _popT = 0;
  void shake() => _shakeT = 0;
  void glow({double delay = 0}) {
    _glowDelay = delay;
    _glowT = 0;
  }

  bool get isAnimating => _popT < 1 || _shakeT < 1 || _glowT < 1;

  @override
  void onTapDown(TapDownEvent event) => game.controller.select(index);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _textCache.clear();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_popT < 1) _popT = min(1, _popT + dt / _popDuration);
    if (_shakeT < 1) _shakeT = min(1, _shakeT + dt / _shakeDuration);
    if (_glowT < 1) {
      if (_glowDelay > 0) {
        _glowDelay -= dt;
      } else {
        _glowT = min(1, _glowT + dt / _glowDuration);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final controller = game.controller;
    final palette = game.palette;
    final selected = controller.selected;
    final value = controller.valueAt(index);
    final selectedValue = selected == null ? 0 : controller.valueAt(selected);
    final rect = size.toRect();
    final inner = RRect.fromRectAndRadius(
      rect.deflate(size.x * 0.06),
      Radius.circular(size.x * 0.18),
    );

    if (index == selected) {
      canvas.drawRRect(inner, Paint()..color = palette.selected);
    } else if (selectedValue != 0 && value == selectedValue) {
      canvas.drawRRect(inner, Paint()..color = palette.sameValue);
    } else if (selected != null && peersOf(selected).contains(index)) {
      canvas.drawRect(rect, Paint()..color = palette.peer);
    }

    if (_glowT < 1 && _glowDelay <= 0) {
      final strength = sin(_glowT * pi);
      canvas.drawRRect(
        inner,
        Paint()..color = palette.glow.withValues(alpha: 0.45 * strength),
      );
    }

    final wrong = controller.isWrong(index);
    if (_shakeT < 1) {
      canvas.drawRRect(
        inner,
        Paint()
          ..color = palette.wrongFlash.withValues(alpha: 0.9 * (1 - _shakeT)),
      );
    }

    if (value != 0) {
      final given = controller.isGiven(index);
      final color = wrong
          ? palette.wrong
          : given
              ? palette.given
              : palette.entry;
      final scale = _popT < 1
          ? 1 + 0.45 * sin(Curves.easeOut.transform(_popT) * pi)
          : 1.0;
      final dx = _shakeT < 1
          ? sin(_shakeT * pi * 7) * size.x * 0.12 * (1 - _shakeT)
          : 0.0;
      _drawText(
        canvas,
        '$value',
        center: Offset(size.x / 2 + dx, size.y / 2),
        fontSize: size.x * 0.58,
        color: color,
        bold: given,
        scale: scale,
      );
    } else {
      final notes = controller.notesAt(index);
      for (final note in notes) {
        final r = (note - 1) ~/ 3, c = (note - 1) % 3;
        _drawText(
          canvas,
          '$note',
          center: Offset(size.x * (c + 0.5) / 3, size.y * (r + 0.5) / 3),
          fontSize: size.x * 0.24,
          color: palette.note,
          bold: false,
        );
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text, {
    required Offset center,
    required double fontSize,
    required Color color,
    required bool bold,
    double scale = 1,
  }) {
    final key =
        '$text|${fontSize.toStringAsFixed(1)}|${color.toARGB32()}|$bold';
    final painter = _textCache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: game.palette.fontFamily,
            fontSize: fontSize,
            color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(scale);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }
}
