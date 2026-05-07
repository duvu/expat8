import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'src/api/backend_api_client.dart';
import 'src/config.dart';
import 'src/data/local_database.dart';
import 'src/data/word_repository.dart';
import 'src/logging/logger.dart';
import 'src/session/learning_session_controller.dart';
import 'src/ui/learning_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  final config = AppConfig.fromEnvironment();
  final database = await LocalDatabase.open();
  final logger = PersistedLogger(
    minimumLevel: AppLogLevel.fromName(config.logLevel),
    write: (entry) async {
      await database.persistLogEntry(entry);
      await database.pruneLogs(
        maxEntries: config.logMaxEntries,
        maxAge: Duration(days: config.logRetentionDays),
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
  final controller = LearningSessionController(repository: repository, logger: logger);

  // Initialize the refresh worker once device ID is known
  try {
    final deviceId = await repository.getOrCreateDeviceId();
    repository.initRefreshWorker(deviceId);
    await repository.syncCacheInventory(deviceId: deviceId);
    unawaited(_runStartupRefreshTask(
      repository.checkAndRunFirstInstallPrefetch,
      logger,
      event: 'app.prefetch.startup_error',
      message: 'First-install prefetch trigger failed at startup.',
    ));
    unawaited(_runStartupRefreshTask(
      repository.checkAndRunDailyRefresh,
      logger,
      event: 'app.daily_refresh.startup_error',
      message: 'Daily refresh trigger failed at startup.',
    ));
  } catch (error) {
    await logger.warning(
      category: AppLogCategory.app,
      event: 'app.refresh.init_error',
      message: 'Vocabulary refresh worker init failed at startup.',
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

Future<void> _runStartupRefreshTask(
  Future<void> Function() action,
  Logger logger, {
  required String event,
  required String message,
}) async {
  try {
    await action();
  } catch (error) {
    await logger.warning(
      category: AppLogCategory.app,
      event: event,
      message: message,
      context: {'error': '$error'},
    );
  }
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
