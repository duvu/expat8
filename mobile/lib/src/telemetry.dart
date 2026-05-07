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

class DebugTelemetrySink implements TelemetrySink {
  @override
  void track(TelemetryEvent event, [Map<String, Object?> properties = const {}]) {
    // Replace with analytics SDK integration when product telemetry is selected.
  }
}
