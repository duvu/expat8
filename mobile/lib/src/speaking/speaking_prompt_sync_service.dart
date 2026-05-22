import '../api/backend_api_client.dart';
import 'speaking_repository.dart';

/// Fetches approved speaking prompts from the backend and upserts them into
/// the local ObjectBox cache for offline drill use.
///
/// Designed to be called once at startup (fire-and-forget). Failure is
/// non-fatal — the drill will use whatever prompts are already cached.
class SpeakingPromptSyncService {
  SpeakingPromptSyncService({
    required BackendApiClient apiClient,
    required SpeakingRepository speakingRepository,
  })  : _apiClient = apiClient,
        _repo = speakingRepository;

  final BackendApiClient _apiClient;
  final SpeakingRepository _repo;

  /// Syncs approved prompts from the backend into local storage.
  ///
  /// Silently ignores network and API errors so the app can still start
  /// without connectivity.
  Future<void> sync() async {
    try {
      final items = await _apiClient.fetchSpeakingPrompts();
      _repo.upsertAllFromSync(items);
    } catch (_) {
      // Non-fatal: drill will fall back to previously-cached prompts.
    }
  }
}
