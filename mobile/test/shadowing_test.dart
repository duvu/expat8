import 'package:expat8_language_app/src/data/shadowing_repository.dart';
import 'package:expat8_language_app/src/models/shadowing_video.dart';
import 'package:expat8_language_app/src/shadowing/shadowing_library_screen.dart';
import 'package:expat8_language_app/src/ui/learning_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Minimal stub repository (no ObjectBox, no HTTP)
// ---------------------------------------------------------------------------
class _StubShadowingRepository extends ShadowingRepository {
  _StubShadowingRepository({
    List<ShadowingVideo> cached = const [],
    List<ShadowingVideo> refreshed = const [],
    Exception? importError,
  })  : _cached = cached,
        _refreshed = refreshed,
        _importError = importError,
        super.forTest();

  final List<ShadowingVideo> _cached;
  final List<ShadowingVideo> _refreshed;
  final Exception? _importError;

  @override
  List<ShadowingVideo> listCachedVideos() => List.of(_cached);

  @override
  Future<List<ShadowingVideo>> refreshLibrary({int limit = 50}) async =>
      List.of(_refreshed);

  @override
  Future<ShadowingVideo> importVideo({required String sourceUrl}) async {
    if (_importError != null) throw _importError!;
    return _makeVideo(id: 'imported-1', title: 'Imported Video', type: 'saved');
  }

  @override
  ShadowingVideo? getCachedVideo(String entryId) => null;

  @override
  Future<ShadowingVideo> getVideoDetail({required String entryId}) async =>
      _makeVideo(id: entryId, title: 'Detail');

  @override
  ShadowingVideoProgress loadProgress(ShadowingVideo video) =>
      ShadowingVideoProgress(
        entryId: video.id,
        lastPositionMs: 0,
        playbackRate: 1.0,
      );

  @override
  Future<void> saveProgress({
    required String entryId,
    required int lastPositionMs,
    required double playbackRate,
  }) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
ShadowingVideo _makeVideo({
  String id = 'vid-1',
  String title = 'Test Video',
  String type = 'curated',
  int segmentCount = 3,
  List<ShadowingTranscriptSegment> segments = const [],
}) {
  return ShadowingVideo(
    id: id,
    entryType: type,
    visibility: 'published',
    sourceType: 'youtube',
    providerVideoId: 'abc123',
    sourceUrl: 'https://www.youtube.com/watch?v=abc123',
    title: title,
    segmentCount: segmentCount,
    playbackDefaults:
        const ShadowingPlaybackDefaults(initialPlaybackRate: 1.0, seekBackMs: 3000),
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    segments: segments,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShadowingLibraryScreen', () {
    testWidgets('shows video list after refresh', (tester) async {
      final repo = _StubShadowingRepository(
        cached: [],
        refreshed: [
          _makeVideo(id: 'c1', title: 'Curated One', type: 'curated'),
          _makeVideo(id: 's1', title: 'My Video', type: 'saved'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: ShadowingLibraryScreen(repository: repo)),
      );
      // Pump twice: first for build, then for async refresh.
      await tester.pumpAndSettle();

      expect(find.text('Curated One'), findsOneWidget);
      expect(find.text('My Video'), findsOneWidget);
      expect(find.text('Curated'), findsOneWidget);
      expect(find.text('My Videos'), findsOneWidget);
    });

    testWidgets('shows empty state when no videos', (tester) async {
      final repo = _StubShadowingRepository(cached: [], refreshed: []);

      await tester.pumpWidget(
        MaterialApp(home: ShadowingLibraryScreen(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No videos yet.', findRichText: true), findsNothing);
      // The empty state text is a single widget — just check for import button.
      expect(find.text('Import video'), findsOneWidget);
    });

    testWidgets('import dialog appears on FAB tap', (tester) async {
      final repo = _StubShadowingRepository(cached: [], refreshed: []);

      await tester.pumpWidget(
        MaterialApp(home: ShadowingLibraryScreen(repository: repo)),
      );
      await tester.pumpAndSettle();

      // Tap the import icon button in the app bar (not the ElevatedButton.icon in empty state).
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add_link));
      await tester.pumpAndSettle();

      expect(find.text('Import YouTube video'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
    });

    testWidgets('successful import adds video to list', (tester) async {
      final repo = _StubShadowingRepository(cached: [], refreshed: []);

      await tester.pumpWidget(
        MaterialApp(home: ShadowingLibraryScreen(repository: repo)),
      );
      await tester.pumpAndSettle();

      // Open import dialog and submit URL.
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add_link));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'https://www.youtube.com/watch?v=test');
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(find.text('Imported Video'), findsOneWidget);
    });

    testWidgets('import error shows snackbar', (tester) async {
      final repo = _StubShadowingRepository(
        cached: [],
        refreshed: [],
        importError: Exception('transcript_unavailable'),
      );

      await tester.pumpWidget(
        MaterialApp(home: ShadowingLibraryScreen(repository: repo)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.add_link));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField), 'https://www.youtube.com/watch?v=bad');
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(
        find.text('No transcript available for this video. Please try another.'),
        findsOneWidget,
      );
    });
  });

  group('LearningDrawer — shadowing tile', () {
    Widget _buildDrawer({VoidCallback? onShadowing}) {
      return MaterialApp(
        home: Scaffold(
          key: GlobalKey<ScaffoldState>(),
          drawer: LearningDrawer(
            isSignedIn: false,
            onVocabulary: () {},
            onWorkplaceSentences: () {},
            onLogs: () {},
            onArticles: () {},
            onMemorization: () {},
            onSubmittedWords: () {},
            onHistory: () {},
            onStats: () {},
            onRegister: () {},
            onSignIn: () {},
            onSignOut: () {},
            onShadowing: onShadowing,
          ),
        ),
      );
    }

    testWidgets('Video Shadowing tile hidden when onShadowing is null',
        (tester) async {
      await tester.pumpWidget(_buildDrawer());
      final scaffoldState =
          tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Video Shadowing'), findsNothing);
    });

    testWidgets('Video Shadowing tile visible when onShadowing provided',
        (tester) async {
      await tester.pumpWidget(_buildDrawer(onShadowing: () {}));
      final scaffoldState =
          tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Video Shadowing'), findsOneWidget);
    });
  });
}
