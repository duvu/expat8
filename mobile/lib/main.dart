import 'dart:async';

import 'package:flutter/material.dart';

import 'src/api/backend_api_client.dart';
import 'src/config.dart';
import 'src/data/local_database.dart';
import 'src/data/word_repository.dart';
import 'src/logging/logger.dart';
import 'src/session/learning_session_controller.dart';
import 'src/ui/learning_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final database = await LocalDatabase.open();
  final logger = PersistedLogger(
    minimumLevel: AppLogLevel.fromName(config.logLevel),
    write: (entry) async {
      await database.persistLogEntry(entry);
      await database.pruneLogs(
        maxEntries: config.logMaxEntries,
        maxAge: config.logRetention,
      );
    },
  );
  database.attachLogger(logger);
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

  await logger.info(
    category: AppLogCategory.app,
    event: 'app.start',
    message: 'App bootstrap completed.',
  );

  runApp(LanguageLearningApp(controller: controller));
}

class LanguageLearningApp extends StatelessWidget {
  const LanguageLearningApp({required this.controller, super.key});

  final LearningSessionController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expat8 Vocabulary',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF256D5A)),
        useMaterial3: true,
      ),
      home: LearningScreen(controller: controller),
    );
  }
}
