/// Initializes an `OnramperClient` once. The native SDK keeps its session
/// across `reset()` / `signOut()` and rejects a second `initialize()` with
/// `invalidStateTransition`, so only the first prepare (or one after a failed
/// attempt) runs it; overlapping prepares share the in-flight call. Create a
/// new instance whenever the client is rebuilt.
class SessionInitializer {
  Future<void>? _initialization;

  Future<void> ensureInitialized(Future<void> Function() initialize) {
    final inFlight = _initialization;
    if (inFlight != null) return inFlight;
    final attempt = initialize();
    _initialization = attempt;
    // A failed attempt is retried on the next prepare.
    attempt.catchError((Object _) {
      if (identical(_initialization, attempt)) _initialization = null;
    });
    return attempt;
  }
}
