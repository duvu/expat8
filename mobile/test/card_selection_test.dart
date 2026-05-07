import 'package:expat8_language_app/src/session/card_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('targets three new cards in a twenty-card window', () {
    final window = CardSelectionWindow();

    expect(window.preferredKind(), CardKind.newWord);
    window.record(CardKind.newWord);
    window.record(CardKind.newWord);
    expect(window.preferredKind(), CardKind.newWord);
    window.record(CardKind.newWord);
    expect(window.preferredKind(), CardKind.review);
    expect(window.windowSize, 20);
    expect(window.targetNewCards, 3);
  });

  test('keeps rolling twenty-card history', () {
    final window = CardSelectionWindow();

    for (var i = 0; i < 22; i++) {
      window.record(CardKind.review);
    }

    expect(window.history.length, 20);
  });
}
