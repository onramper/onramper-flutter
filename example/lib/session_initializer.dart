/// Initializes an `OnramperClient` once. The native SDK keeps its session
/// across `reset()` / `signOut()` and rejects a second `initialize()` with
/// `invalidStateTransition`, so only the first prepare (or one after a failed
/// attempt) runs it. Create a new instance whenever the client is rebuilt.
class SessionInitializer {
  bool _initialized = false;

  Future<void> ensureInitialized(Future<void> Function() initialize) async {
    if (_initialized) return;
    await initialize();
    _initialized = true;
  }
}
