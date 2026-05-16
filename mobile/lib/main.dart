import 'dart:async';

import 'package:flutter/material.dart';

import 'src/api/backend_api_client.dart';
import 'src/config.dart';
import 'src/data/article_repository.dart';
import 'src/data/content_pack_sync_service.dart';
import 'src/data/local_database.dart';
import 'src/data/workplace_sentence_repository.dart';
import 'src/data/word_repository.dart';
import 'src/logging/logger.dart';
import 'src/session/learning_session_controller.dart';
import 'src/speaking/audio_file_manager.dart';
import 'src/speaking/speaking_audio_service.dart';
import 'src/speaking/speaking_prompt_sync_service.dart';
import 'src/speaking/speaking_repository.dart';
import 'src/ui/learning_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final database = await LocalDatabase.open();
  // Persist log entries only — pruning is expensive (O(n log n) over the whole
  // log table) and must not run on every log call or the UI hot path stalls
  // after a few hundred entries accumulate. A periodic timer below handles
  // pruning out of band.
  final logger = PersistedLogger(
    minimumLevel: AppLogLevel.fromName(config.logLevel),
    write: (entry) => database.persistLogEntry(entry),
  );
  database.attachLogger(logger);

  // Prune log table every 5 minutes (and once at startup) to enforce the
  // retention/cap budget without blocking individual log writes.
  unawaited(database.pruneLogs(
    maxEntries: config.logMaxEntries,
    maxAge: config.logRetention,
  ));
  Timer.periodic(const Duration(minutes: 5), (_) {
    unawaited(database.pruneLogs(
      maxEntries: config.logMaxEntries,
      maxAge: config.logRetention,
    ));
  });
  final apiClient = BackendApiClient(
    baseUrl: config.backendBaseUrl,
    timeout: config.newWordTimeout,
    appId: config.appCredentialAppId,
    appSecret: config.appCredentialSecret,
    logger: logger,
  );
  final articleRepository = ArticleRepository(apiClient: apiClient);
  final repository = WordRepository(
    database: database,
    apiClient: apiClient,
    logger: logger,
    config: config,
  );
  final workplaceSentenceRepository = WorkplaceSentenceRepository(
    database: database,
    apiClient: apiClient,
    logger: logger,
  );
  final controller =
      LearningSessionController(repository: repository, logger: logger);

  // Callback invoked on app resume to flush the pending event queue promptly.
  VoidCallback? onAppResumeSyncEvents;

  // Seed bundled vocabulary on first launch so the user can start studying
  // immediately — no waiting on a backend round-trip. The periodic top-up
  // timer in the controller refreshes inventory in the background afterwards.
  try {
    await repository.seedFromBundleIfEmpty(
      languages: config.supportedLearningLanguages,
    );
    final deviceId = await repository.getOrCreateDeviceId();
    repository.initRefreshWorker(deviceId);
    unawaited(repository.syncCacheInventory(deviceId: deviceId));
    // Flush the study/speaking event queue at startup and every 3 minutes so
    // events from drill sessions reach the backend even when no card swipe
    // triggers a cache sync.
    unawaited(repository.syncPendingEvents(deviceId: deviceId));
    Timer.periodic(const Duration(minutes: 3), (_) {
      unawaited(repository.syncPendingEvents(deviceId: deviceId));
    });
    onAppResumeSyncEvents = () {
      unawaited(repository.syncPendingEvents(deviceId: deviceId));
    };
    unawaited(repository.topUpInventoryIfNeeded());
  } catch (error) {
    await logger.warning(
      category: AppLogCategory.app,
      event: 'app.refresh.init_error',
      message: 'Vocabulary inventory init failed at startup.',
      context: {'error': '$error'},
    );
  }

  // Sync content-pack version watermarks in background so the app knows when
  // new vocabulary is available without blocking the local card session.
  final contentPackSyncService = ContentPackSyncService(
    apiClient: apiClient,
    database: database,
    logger: logger,
    language: config.supportedLearningLanguages.isNotEmpty
        ? config.supportedLearningLanguages.first
        : 'en',
  );
  unawaited(contentPackSyncService.sync());

  // Build speaking infrastructure (gated by feature flag).
  SpeakingRepository? speakingRepository;
  SpeakingPromptSyncService? speakingPromptSyncService;
  if (config.speakingFoundationEnabled) {
    final fileManager = AudioFileManager();
    final audioService = SpeakingAudioService(fileManager: fileManager);
    speakingRepository = SpeakingRepository(
      database: database,
      audioService: audioService,
      fileManager: fileManager,
    );
    speakingPromptSyncService = SpeakingPromptSyncService(
      apiClient: apiClient,
      speakingRepository: speakingRepository,
    );
    // Run 30-day audio retention cleanup once at startup — out of band.
    unawaited(speakingRepository.runRetentionCleanup());
    // Sync approved prompts for offline drill use — out of band.
    unawaited(speakingPromptSyncService.sync());
  }

  await logger.info(
    category: AppLogCategory.app,
    event: 'app.start',
    message: 'App bootstrap completed.',
  );

  runApp(LanguageLearningApp(
      controller: controller,
      articleRepository: articleRepository,
      workplaceSentenceRepository: workplaceSentenceRepository,
      contentPackSyncService: contentPackSyncService,
      speakingRepository: speakingRepository,
    speakingPromptSyncService: speakingPromptSyncService,
    onResumeSyncEvents: onAppResumeSyncEvents,
  ));
}

class LanguageLearningApp extends StatefulWidget {
  const LanguageLearningApp({
    required this.controller,
    required this.articleRepository,
    required this.workplaceSentenceRepository,
    required this.contentPackSyncService,
    this.speakingRepository,
    this.speakingPromptSyncService,
    this.onResumeSyncEvents,
    super.key,
  });

  final LearningSessionController controller;
  final ArticleRepository articleRepository;
  final WorkplaceSentenceRepository workplaceSentenceRepository;
  final ContentPackSyncService contentPackSyncService;
  final SpeakingRepository? speakingRepository;
  final SpeakingPromptSyncService? speakingPromptSyncService;
  final VoidCallback? onResumeSyncEvents;

  @override
  State<LanguageLearningApp> createState() => _LanguageLearningAppState();
}

class _LanguageLearningAppState extends State<LanguageLearningApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-sync content-pack watermarks on foreground to pick up new vocabulary
      // published since the last session — non-blocking, local session unaffected.
      unawaited(widget.contentPackSyncService.sync());
      // Re-sync speaking prompts when the app comes back to the foreground
      // so stale prompts are removed and new ones are picked up.
      unawaited(widget.speakingPromptSyncService?.sync());
      // Flush queued study/speaking events to the backend.
      widget.onResumeSyncEvents?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expat8 Vocabulary',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF256D5A)),
        useMaterial3: true,
      ),
      home: LearningScreen(
        controller: widget.controller,
        articleRepository: widget.articleRepository,
        workplaceSentenceRepository: widget.workplaceSentenceRepository,
        speakingRepository: widget.speakingRepository,
      ),
    );
  }
}
