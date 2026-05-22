import '../api/backend_api_client.dart';
import '../models/memorization_passage.dart';

class MemorizationRepository {
  MemorizationRepository({required this.apiClient});

  final BackendApiClient apiClient;

  Future<List<MemorizationPassage>> listPassages({
    required String sessionToken,
  }) =>
      apiClient.listPassages(sessionToken: sessionToken);

  Future<MemorizationPassage> createPassage({
    required String sessionToken,
    required String title,
    required String language,
    required String rawText,
  }) =>
      apiClient.createPassage(
        sessionToken: sessionToken,
        title: title,
        language: language,
        rawText: rawText,
      );

  Future<MemorizationPassage> getPassage({
    required String sessionToken,
    required String passageId,
  }) =>
      apiClient.getPassage(
        sessionToken: sessionToken,
        passageId: passageId,
      );

  Future<void> deletePassage({
    required String sessionToken,
    required String passageId,
  }) =>
      apiClient.deletePassage(
        sessionToken: sessionToken,
        passageId: passageId,
      );

  Future<List<MemorizationSegmentProgress>> getPassageProgress({
    required String sessionToken,
    required String passageId,
  }) =>
      apiClient.getPassageProgress(
        sessionToken: sessionToken,
        passageId: passageId,
      );

  Future<void> upsertSegmentProgress({
    required String sessionToken,
    required List<Map<String, dynamic>> progressUpdates,
  }) =>
      apiClient.upsertSegmentProgress(
        sessionToken: sessionToken,
        progressUpdates: progressUpdates,
      );
}
