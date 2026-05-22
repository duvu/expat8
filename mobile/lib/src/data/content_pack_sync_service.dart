import '../api/backend_api_client.dart';
import '../logging/logger.dart';
import 'local_database.dart';

/// Synchronises content-pack version watermarks with the backend.
///
/// On each [sync] call the service:
///   1. Reads the locally-stored version watermark for [language].
///   2. Calls `GET /v1/content-packs?language=…&after_version=…` to discover
///      packs newer than the local watermark.
///   3. If new packs are found it advances the watermark to the highest version.
///
/// The service is designed to be called fire-and-forget at startup and on
/// session resume. Any failure is treated as non-fatal: the app continues
/// using the vocabulary already cached locally.
class ContentPackSyncService {
  ContentPackSyncService({
    required BackendApiClient apiClient,
    required LocalDatabase database,
    Logger? logger,
    String language = 'en',
    String? sessionToken,
  })  : _apiClient = apiClient,
        _database = database,
        _logger = logger ?? const NoopLogger(),
        _language = language,
        _sessionToken = sessionToken;

  final BackendApiClient _apiClient;
  final LocalDatabase _database;
  final Logger _logger;
  final String _language;
  final String? _sessionToken;

  static String _settingKey(String language) =>
      'content_pack_version_watermark_$language';

  /// Syncs the content-pack version watermark with the backend.
  ///
  /// Returns the number of new packs discovered (0 when already up-to-date
  /// or on any error).
  Future<int> sync() async {
    try {
      final raw = await _database.getSetting(_settingKey(_language));
      final afterVersion = raw != null ? int.tryParse(raw) : null;

      await _logger.info(
        category: AppLogCategory.sync,
        event: 'content_pack_sync.start',
        message: 'Checking for new content packs.',
        context: {
          'language': _language,
          'after_version': afterVersion,
        },
      );

      final packs = await _apiClient.listContentPacks(
        language: _language,
        afterVersion: afterVersion,
        sessionToken: _sessionToken,
      );

      if (packs.isEmpty) {
        await _logger.info(
          category: AppLogCategory.sync,
          event: 'content_pack_sync.up_to_date',
          message: 'Content packs are up to date.',
          context: {'language': _language, 'after_version': afterVersion},
        );
        return 0;
      }

      // Advance the local watermark to the highest version in the response.
      final maxVersion = packs.map((p) => p.version).reduce(
            (a, b) => a > b ? a : b,
          );
      await _database.setSetting(_settingKey(_language), maxVersion.toString());

      await _logger.info(
        category: AppLogCategory.sync,
        event: 'content_pack_sync.updated',
        message: 'Content pack watermark advanced.',
        context: {
          'language': _language,
          'new_packs': packs.length,
          'max_version': maxVersion,
        },
      );

      return packs.length;
    } catch (error) {
      // Non-fatal: ongoing local session is unaffected.
      await _logger.warning(
        category: AppLogCategory.sync,
        event: 'content_pack_sync.failed',
        message:
            'Content pack sync failed — session continues with local data.',
        context: {
          'language': _language,
          'error': '$error',
          'session_continuity': 'unaffected',
        },
      );
      return 0;
    }
  }
}
