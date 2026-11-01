import 'skill_mastery.dart';

/// Where answers to skill-tagged questions are recorded. Games only know
/// this interface, so a game never touches storage or the signed-in account.
abstract interface class SkillAnswerSink {
  void record(SkillAnswer answer);
}
