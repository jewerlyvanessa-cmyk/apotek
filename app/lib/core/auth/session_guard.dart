/// Callback global agar [dioProvider] tidak bergantung pada [authProvider].
class SessionGuard {
  SessionGuard._();

  static final SessionGuard instance = SessionGuard._();

  Future<void> Function()? onSessionExpired;

  Future<void> notifySessionExpired() async {
    await onSessionExpired?.call();
  }
}
