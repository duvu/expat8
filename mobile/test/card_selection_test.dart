import 'package:expat8_language_app/src/session/card_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('targets three new cards in a ten-card window', () {
    final window = CardSelectionWindow();

    expect(window.preferredKind(), CardKind.newWord);
    window.record(CardKind.newWord);
    window.record(CardKind.newWord);
    expect(window.preferredKind(), CardKind.newWord);
    window.record(CardKind.newWord);
    expect(window.preferredKind(), CardKind.review);
  });

  test('keeps rolling ten-card history', () {
    final window = CardSelectionWindow();

    for (var i = 0; i < 12; i++) {
      window.record(CardKind.review);
    }

    expect(window.history.length, 10);
  });
}
