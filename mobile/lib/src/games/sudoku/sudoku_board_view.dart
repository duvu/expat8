import 'package:flutter/material.dart';

import 'sudoku_game_controller.dart';
import 'sudoku_generator.dart';

/// The 9x9 grid. Tapping a cell selects it.
class SudokuBoardView extends StatelessWidget {
  const SudokuBoardView({required this.controller, super.key});

  final SudokuGameController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = controller.selected;
    final selectedValue = selected == null ? 0 : controller.valueAt(selected);
    final peers = selected == null ? const <int>{} : peersOf(selected).toSet();

    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.onSurface, width: 2),
        ),
        child: Column(
          children: [
            for (var row = 0; row < 9; row++)
              Expanded(
                child: Row(
                  children: [
                    for (var col = 0; col < 9; col++)
                      Expanded(
                        child: _SudokuCell(
                          index: row * 9 + col,
                          controller: controller,
                          isSelected: selected == row * 9 + col,
                          isPeer: peers.contains(row * 9 + col),
                          sharesValue: selectedValue != 0 &&
                              controller.valueAt(row * 9 + col) ==
                                  selectedValue,
                        ),
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

class _SudokuCell extends StatelessWidget {
  const _SudokuCell({
    required this.index,
    required this.controller,
    required this.isSelected,
    required this.isPeer,
    required this.sharesValue,
  });

  final int index;
  final SudokuGameController controller;
  final bool isSelected;
  final bool isPeer;
  final bool sharesValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final row = index ~/ 9, col = index % 9;
    final value = controller.valueAt(index);
    final given = controller.isGiven(index);
    final wrong = controller.isWrong(index);

    final Color background;
    if (isSelected) {
      background = scheme.primaryContainer;
    } else if (sharesValue) {
      background = scheme.secondaryContainer;
    } else if (isPeer) {
      background = scheme.surfaceContainerHighest;
    } else {
      background = scheme.surface;
    }

    final thin = BorderSide(color: scheme.outlineVariant, width: 0.5);
    final thick = BorderSide(color: scheme.onSurface, width: 1.5);

    return Semantics(
      label: 'Row ${row + 1}, column ${col + 1}, '
          '${value == 0 ? 'empty' : '$value'}${given ? ', given' : ''}'
          '${wrong ? ', incorrect' : ''}',
      selected: isSelected,
      button: true,
      child: GestureDetector(
        key: ValueKey('sudoku-cell-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.select(index),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            border: Border(
              right: col == 8 ? BorderSide.none : (col % 3 == 2 ? thick : thin),
              bottom:
                  row == 8 ? BorderSide.none : (row % 3 == 2 ? thick : thin),
            ),
          ),
          alignment: Alignment.center,
          child: value != 0
              ? FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      '$value',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: given ? FontWeight.w700 : FontWeight.w400,
                        color: wrong
                            ? scheme.error
                            : given
                                ? scheme.onSurface
                                : scheme.primary,
                      ),
                    ),
                  ),
                )
              : _NotesGrid(notes: controller.notesAt(index)),
        ),
      ),
    );
  }
}

class _NotesGrid extends StatelessWidget {
  const _NotesGrid({required this.notes});

  final Set<int> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.expand();
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Column(
        children: [
          for (var r = 0; r < 3; r++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < 3; c++)
                    Expanded(
                      child: FittedBox(
                        child: Text(
                          notes.contains(r * 3 + c + 1) ? '${r * 3 + c + 1}' : ' ',
                          style: style,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
