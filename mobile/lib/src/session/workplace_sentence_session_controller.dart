import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../data/workplace_sentence_repository.dart';
import '../logging/logger.dart';
import '../models/workplace_sentence.dart';

class WorkplaceSentenceSessionController extends ChangeNotifier {
  WorkplaceSentenceSessionController({
    required this.repository,
    Logger? logger,
    AppConfig? config,
  })  : _logger = logger ?? const NoopLogger(),
        _config = config ?? AppConfig.fromEnvironment() {
    _activeLanguage = _config.supportedLearningLanguages.contains('en')
        ? 'en'
        : _config.defaultLearningLanguage;
  }

  final WorkplaceSentenceRepository repository;
  final Logger _logger;
  final AppConfig _config;

  final Duration _inventoryTopUpInterval = const Duration(hours: 1);
  Timer? _inventoryTimer;
  bool _topUpInFlight = false;
  String? _deviceId;
  late String _activeLanguage;

  WorkplaceSentence? currentSentence;
  bool isLoading = false;
  String? statusMessage;

  Future<void> loadInitial() async {
    if (isLoading) {
      return;
    }
    isLoading = true;
    notifyListeners();
    try {
      await repository.seedFromBundleIfEmpty(languages: [_activeLanguage]);
      _deviceId ??= await repository.getOrCreateDeviceId();
      repository.initRefreshWorker(_deviceId!);
      repository.setActiveLanguage(_activeLanguage);
      await _loadNextSentence();
      _startInventoryTimer();
      unawaited(_triggerInventoryTopUp());
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> showNextSentence() async {
    if (isLoading) {
      return;
    }
    isLoading = true;
    notifyListeners();
    try {
      await _loadNextSentence();
      unawaited(_triggerInventoryTopUp());
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadNextSentence() async {
    final next = await repository.nextSentence(language: _activeLanguage);
    if (next == null) {
      currentSentence = null;
      statusMessage = 'No workplace sentence is available yet.';
      notifyListeners();
      return;
    }

    currentSentence = next;
    statusMessage = null;
    await repository.markSentenceSeen(
      sentence: next,
      now: DateTime.now().toUtc(),
    );
    notifyListeners();
  }

  void _startInventoryTimer() {
    _inventoryTimer?.cancel();
    _inventoryTimer = Timer.periodic(_inventoryTopUpInterval, (_) {
      unawaited(_triggerInventoryTopUp());
    });
  }

  Future<void> _triggerInventoryTopUp() async {
    if (_topUpInFlight) {
      return;
    }
    _topUpInFlight = true;
    try {
      await repository.topUpInventoryIfNeeded();
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.sync,
        event: 'workplace_sentences.top_up.failed',
        message: 'Background workplace sentence top-up failed.',
        context: {'error': '$error'},
      );
    } finally {
      _topUpInFlight = false;
    }
  }

  @override
  void dispose() {
    _inventoryTimer?.cancel();
    super.dispose();
  }
}
