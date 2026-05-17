import 'vocabulary_word.dart';
import 'workplace_sentence.dart';

enum LearningItemKind { vocabulary, sentence }

enum LearningItemState { learned, remembered, difficult }

class LearningItemSnapshot {
  LearningItemSnapshot({
    required this.kind,
    required this.localId,
    required this.title,
    required this.subtitle,
    List<String> tags = const [],
  }) : tags = List.unmodifiable(tags);

  factory LearningItemSnapshot.fromVocabularyWord(VocabularyWord word) {
    final tags = <String>[
      word.language.toUpperCase(),
    ];
    final partOfSpeech = word.partOfSpeech?.trim();
    if (partOfSpeech != null && partOfSpeech.isNotEmpty) {
      tags.add(partOfSpeech);
    }
    if (word.entryType.trim().isNotEmpty && word.entryType != 'word') {
      tags.add(word.entryType);
    }
    if (word.difficulty.trim().isNotEmpty) {
      tags.add(word.difficulty);
    }
    return LearningItemSnapshot(
      kind: LearningItemKind.vocabulary,
      localId: word.localId,
      title: word.term,
      subtitle: word.meaningVi,
      tags: tags,
    );
  }

  factory LearningItemSnapshot.fromWorkplaceSentence(WorkplaceSentence sentence) {
    final tags = <String>[
      sentence.language.toUpperCase(),
    ];
    final topic = sentence.topic?.trim();
    if (topic != null && topic.isNotEmpty) {
      tags.add(topic);
    }
    final sourceTitle = sentence.sourceTitle?.trim();
    if (sourceTitle != null && sourceTitle.isNotEmpty) {
      tags.add(sourceTitle);
    }
    if (sentence.isBundled) {
      tags.add('Bundled');
    }
    return LearningItemSnapshot(
      kind: LearningItemKind.sentence,
      localId: sentence.localId,
      title: sentence.text,
      subtitle: sentence.meaningVi,
      tags: tags,
    );
  }

  factory LearningItemSnapshot.fromJson(Map<String, dynamic> json) {
    return LearningItemSnapshot(
      kind: LearningItemKind.values.byName(json['kind'] as String),
      localId: json['local_id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      tags: List<String>.from(json['tags'] as List? ?? const []),
    );
  }

  final LearningItemKind kind;
  final String localId;
  final String title;
  final String subtitle;
  final List<String> tags;

  String get storageKey => '${kind.name}:$localId';

  String get kindLabel {
    return switch (kind) {
      LearningItemKind.vocabulary => 'Vocabulary',
      LearningItemKind.sentence => 'Sentence',
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'kind': kind.name,
      'local_id': localId,
      'title': title,
      'subtitle': subtitle,
      'tags': tags,
    };
  }
}

class LearningHistoryEntry {
  LearningHistoryEntry({
    required this.snapshot,
    required this.state,
    required this.occurredAt,
  });

  factory LearningHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LearningHistoryEntry(
      snapshot: LearningItemSnapshot.fromJson(
        json['snapshot'] as Map<String, dynamic>,
      ),
      state: LearningItemState.values.byName(json['state'] as String),
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        json['occurred_at_ms'] as int,
        isUtc: true,
      ),
    );
  }

  final LearningItemSnapshot snapshot;
  final LearningItemState state;
  final DateTime occurredAt;

  String get stateLabel {
    return switch (state) {
      LearningItemState.learned => 'Learned',
      LearningItemState.remembered => 'Remembered',
      LearningItemState.difficult => 'Difficult',
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'snapshot': snapshot.toJson(),
      'state': state.name,
      'occurred_at_ms': occurredAt.toUtc().millisecondsSinceEpoch,
    };
  }
}

class LearningProgressTotals {
  const LearningProgressTotals({
    required this.learned,
    required this.remembered,
    required this.difficult,
  });

  final int learned;
  final int remembered;
  final int difficult;

  int get total => learned + remembered + difficult;
}
