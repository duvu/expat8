enum TelemetryEvent {
  cardShown,
  newWordRequested,
  newWordBackendSuccess,
  newWordBackendTimeout,
  newWordLocalFallback,
  reviewWordShown,
  studyRatingSubmitted,
  syncSuccess,
  syncFailed,
  localCachePruned,
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
