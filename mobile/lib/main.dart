import 'package:flutter/material.dart';

import 'src/api/backend_api_client.dart';
import 'src/config.dart';
import 'src/data/local_database.dart';
import 'src/data/word_repository.dart';
import 'src/session/learning_session_controller.dart';
import 'src/ui/learning_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final database = await LocalDatabase.open();
  final apiClient = BackendApiClient(
    baseUrl: config.backendBaseUrl,
    timeout: config.newWordTimeout,
  );
  final repository = WordRepository(database: database, apiClient: apiClient);
  final controller = LearningSessionController(repository: repository);

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
