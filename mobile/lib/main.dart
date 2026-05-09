import 'dart:async';

import 'package:flutter/material.dart';

import 'src/api/backend_api_client.dart';
import 'src/config.dart';
import 'src/data/local_database.dart';
import 'src/data/word_repository.dart';
import 'src/logging/logger.dart';
import 'src/session/learning_session_controller.dart';
import 'src/speaking/audio_file_manager.dart';
import 'src/speaking/speaking_audio_service.dart';
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
  final repository = WordRepository(
    database: database,
    apiClient: apiClient,
    logger: logger,
    config: config,
  );
  final controller =
      LearningSessionController(repository: repository, logger: logger);

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
    unawaited(repository.topUpInventoryIfNeeded());
  } catch (error) {
    await logger.warning(
      category: AppLogCategory.app,
      event: 'app.refresh.init_error',
      message: 'Vocabulary inventory init failed at startup.',
      context: {'error': '$error'},
    );
  }

  // Build speaking infrastructure (gated by feature flag).
  SpeakingRepository? speakingRepository;
  if (config.speakingFoundationEnabled) {
    final fileManager = AudioFileManager();
    final audioService = SpeakingAudioService(fileManager: fileManager);
    speakingRepository = SpeakingRepository(
      database: database,
      audioService: audioService,
      fileManager: fileManager,
    );
    // Run 30-day audio retention cleanup once at startup — out of band.
    unawaited(speakingRepository.runRetentionCleanup());
  }

  await logger.info(
    category: AppLogCategory.app,
    event: 'app.start',
    message: 'App bootstrap completed.',
  );

  runApp(LanguageLearningApp(
    controller: controller,
    speakingRepository: speakingRepository,
  ));
}

class LanguageLearningApp extends StatelessWidget {
  const LanguageLearningApp({
    required this.controller,
    this.speakingRepository,
    super.key,
  });

  final LearningSessionController controller;
  final SpeakingRepository? speakingRepository;

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
        controller: controller,
        speakingRepository: speakingRepository,
      ),
    );
  }
}
