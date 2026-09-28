/// The five Sudoku difficulty levels, from most to fewest given digits.
enum SudokuDifficulty {
  beginner(label: 'Beginner', targetGivens: 45),
  easy(label: 'Easy', targetGivens: 38),
  medium(label: 'Medium', targetGivens: 32),
  hard(label: 'Hard', targetGivens: 28),
  expert(label: 'Expert', targetGivens: 24);

  const SudokuDifficulty({required this.label, required this.targetGivens});

  final String label;

  /// Number of pre-filled cells the generator aims for. The generator never
  /// removes a digit if that would allow a second solution, so a puzzle can
  /// end up with a few more givens than this.
  final int targetGivens;

  static SudokuDifficulty fromName(String? name) => SudokuDifficulty.values
      .firstWhere((d) => d.name == name, orElse: () => SudokuDifficulty.easy);
}
