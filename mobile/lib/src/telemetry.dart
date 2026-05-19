enum TelemetryEvent {
  cardShown,
  newWordRequested,
  newWordSwipeRequested,
  recentReviewSwipeRequested,
  newWordLocalFallback,
  newWordFallbackMiss,
  recentReviewHit,
  recentReviewMiss,
  reviewWordShown,
  studyRatingSubmitted,
  authRegisterSuccess,
  authRegisterFailure,
  authSignInSuccess,
  authSignInFailure,
  authSignOutSuccess,
  authSignOutFailure,
}

abstract class TelemetrySink {
  void track(TelemetryEvent event, [Map<String, Object?> properties = const {}]);
}

class NoopTelemetrySink implements TelemetrySink {
  @override
  void track(TelemetryEvent event, [Map<String, Object?> properties = const {}]) {
    // No-op implementation. Replace with analytics SDK when ready.
  }
}

/// Backward-compatible alias.
typedef DebugTelemetrySink = NoopTelemetrySink;
