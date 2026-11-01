import 'dart:async';

import '../data/local_database.dart';
import 'skill_answer_sink.dart';
import 'skill_mastery.dart';

/// Stores answers in the local database under the signed-in account at the
/// time of the answer (null when signed out).
class LocalSkillAnswerSink implements SkillAnswerSink {
  LocalSkillAnswerSink(this.database);

  final LocalDatabase database;

  @override
  void record(SkillAnswer answer) {
    // Bookkeeping must never slow down or break a game.
    unawaited(_store(answer).catchError((Object _) {}));
  }

  Future<void> _store(SkillAnswer answer) async {
    final owner = (await database.loadUserSession())?.userId;
    await database.addSkillAnswer(answer, ownerUserId: owner);
  }
}
