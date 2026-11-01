import 'dart:convert';

/// A curriculum file that cannot be used (the message names the skill).
class CurriculumException implements Exception {
  CurriculumException(this.message);

  final String message;

  @override
  String toString() => 'CurriculumException: $message';
}

/// One authored question a reviewer can judge without running the app.
class SkillExample {
  const SkillExample({required this.question, required this.answer});

  final String question;
  final String answer;
}

/// Something a learner can get better at. The id is stable; [grade] is only
/// where the school curriculum usually teaches it, never a limit.
class Skill {
  const Skill({
    required this.id,
    required this.topicId,
    required this.grade,
    required this.title,
    required this.prerequisites,
    required this.example,
  });

  final String id;
  final String topicId;
  final int grade;
  final String title;
  final List<String> prerequisites;
  final SkillExample example;

  /// The subject is the first segment of the id (`math.frac.x` → `math`).
  String get subject => subjectOf(id);
}

String subjectOf(String skillId) => skillId.split('.').first;

class Topic {
  const Topic({required this.id, required this.title});

  final String id;
  final String title;
}

/// The skills of one subject, indexed for prerequisites and ordering.
class Curriculum {
  Curriculum._(this.subject, this.version, this.topics, this.skills)
      : _byId = {for (final s in skills) s.id: s};

  /// Parses and validates a curriculum file. Throws [CurriculumException]
  /// for duplicate ids, unknown prerequisites, cycles or a missing example.
  factory Curriculum.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'] as String;
    final topics = [
      for (final t in json['topics'] as List)
        Topic(id: (t as Map)['id'] as String, title: t['title'] as String),
    ];
    final topicIds = {for (final t in topics) t.id};
    final skills = <Skill>[];
    for (final raw in json['skills'] as List) {
      final s = raw as Map<String, dynamic>;
      final id = s['id'] as String;
      final example = s['example'] as Map<String, dynamic>?;
      final question = example?['question'] as String?;
      final answer = example?['answer'] as String?;
      if (question == null ||
          question.isEmpty ||
          answer == null ||
          answer.isEmpty) {
        throw CurriculumException('skill $id has no example');
      }
      if (!id.startsWith('$subject.')) {
        throw CurriculumException('skill $id is not in subject $subject');
      }
      if (!topicIds.contains(s['topic'])) {
        throw CurriculumException('skill $id has unknown topic ${s['topic']}');
      }
      skills.add(Skill(
        id: id,
        topicId: s['topic'] as String,
        grade: (s['grade'] as num).toInt(),
        title: s['title'] as String,
        prerequisites: [
          for (final p in s['prerequisites'] as List) p as String
        ],
        example: SkillExample(question: question, answer: answer),
      ));
    }
    _validate(skills);
    return Curriculum._(
        subject, (json['version'] as num).toInt(), topics, skills);
  }

  factory Curriculum.parse(String source) =>
      Curriculum.fromJson(jsonDecode(source) as Map<String, dynamic>);

  final String subject;
  final int version;
  final List<Topic> topics;
  final List<Skill> skills;
  final Map<String, Skill> _byId;

  Skill? skill(String id) => _byId[id];

  bool contains(String id) => _byId.containsKey(id);

  List<Skill> skillsOfTopic(String topicId) => [
        for (final s in skills)
          if (s.topicId == topicId) s
      ];

  /// Skills not in [done] whose prerequisites are all in [done]: what a
  /// learner can start next, whatever their grade.
  List<Skill> unlockedBy(Set<String> done) => [
        for (final s in skills)
          if (!done.contains(s.id) && s.prerequisites.every(done.contains)) s,
      ];

  static void _validate(List<Skill> skills) {
    final ids = <String>{};
    for (final s in skills) {
      if (!ids.add(s.id)) {
        throw CurriculumException('duplicate skill ${s.id}');
      }
    }
    for (final s in skills) {
      for (final p in s.prerequisites) {
        if (!ids.contains(p)) {
          throw CurriculumException('skill ${s.id} requires unknown skill $p');
        }
      }
    }
    final byId = {for (final s in skills) s.id: s};
    final settled = <String>{};
    final visiting = <String>{};
    void visit(Skill s) {
      if (settled.contains(s.id)) return;
      if (!visiting.add(s.id)) {
        throw CurriculumException('prerequisite cycle at skill ${s.id}');
      }
      for (final p in s.prerequisites) {
        visit(byId[p]!);
      }
      visiting.remove(s.id);
      settled.add(s.id);
    }

    skills.forEach(visit);
  }
}
