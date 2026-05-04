enum CardKind { newWord, review }

class CardSelectionWindow {
  CardSelectionWindow({this.windowSize = 10, this.targetNewCards = 3});

  final int windowSize;
  final int targetNewCards;
  final List<CardKind> _history = [];

  CardKind preferredKind() {
    final newCount = _history.where((kind) => kind == CardKind.newWord).length;
    return newCount < targetNewCards ? CardKind.newWord : CardKind.review;
  }

  void record(CardKind kind) {
    _history.add(kind);
    if (_history.length > windowSize) {
      _history.removeAt(0);
    }
  }

  List<CardKind> get history => List.unmodifiable(_history);
}
