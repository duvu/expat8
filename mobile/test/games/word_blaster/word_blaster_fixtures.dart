import 'package:expat8_language_app/src/models/vocabulary_word.dart';

final _now = DateTime.utc(2026, 9, 28, 12);

VocabularyWord vocab(
  String term,
  String meaning, {
  String pos = 'noun',
  String level = 'A1',
  WordStatus status = WordStatus.newWord,
  DateTime? nextReviewAt,
  DateTime? lastSeenAt,
  List<String> topics = const ['general'],
  String? example,
  String language = 'en',
  String entryType = 'word',
}) =>
    VocabularyWord(
      localId: 'local_$term',
      serverWordId: 'server_$term',
      term: term,
      language: language,
      meaningVi: meaning,
      partOfSpeech: pos,
      ipa: '/$term/',
      vietnamesePronunciation: term,
      example: example ?? 'I like the $term very much.',
      exampleVi: 'Tôi rất thích $meaning.',
      difficulty: level,
      topics: topics,
      status: status,
      lastSeenAt: lastSeenAt,
      nextReviewAt: nextReviewAt,
      createdAt: _now,
      updatedAt: _now,
      entryType: entryType,
    );

/// 30 distinct nouns/adjectives with distinct meanings.
List<VocabularyWord> sampleVocabulary() {
  const pairs = [
    ('apple', 'quả táo'),
    ('bridge', 'cây cầu'),
    ('candle', 'cây nến'),
    ('doctor', 'bác sĩ'),
    ('engine', 'động cơ'),
    ('forest', 'khu rừng'),
    ('garden', 'khu vườn'),
    ('hammer', 'cái búa'),
    ('island', 'hòn đảo'),
    ('jacket', 'áo khoác'),
    ('kitchen', 'nhà bếp'),
    ('ladder', 'cái thang'),
    ('market', 'chợ'),
    ('needle', 'cây kim'),
    ('ocean', 'đại dương'),
    ('pencil', 'bút chì'),
    ('queen', 'nữ hoàng'),
    ('river', 'dòng sông'),
    ('salary', 'tiền lương'),
    ('ticket', 'vé'),
    ('uncle', 'chú'),
    ('valley', 'thung lũng'),
    ('window', 'cửa sổ'),
    ('yard', 'sân'),
    ('zebra', 'ngựa vằn'),
    ('reliable', 'đáng tin cậy'),
    ('curious', 'tò mò'),
    ('brave', 'dũng cảm'),
    ('honest', 'trung thực'),
    ('polite', 'lịch sự'),
  ];
  return [
    for (var i = 0; i < pairs.length; i++)
      vocab(
        pairs[i].$1,
        pairs[i].$2,
        pos: i >= 25 ? 'adjective' : 'noun',
        level: ['A1', 'A2', 'B1'][i % 3],
      ),
  ];
}
