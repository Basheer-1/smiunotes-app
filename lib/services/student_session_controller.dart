import 'mobile_auth_api.dart';
import 'secure_session_store.dart';

/// Implementations must validate refresh tokens and live reader grants on
/// the server. Local token presence alone never authorizes access.
typedef RenewStudentSession = Future<MobileSession> Function(String refreshToken);
typedef RevokeStudentSession = Future<void> Function(String accessToken);

class StudentSessionController {
  factory StudentSessionController({
    required SessionVault vault,
    required RenewStudentSession renew,
    required RevokeStudentSession revoke,
  }) => StudentSessionController._(vault, renew, revoke);

  StudentSessionController._(this._vault, this._renew, this._revoke);

  final SessionVault _vault;
  final RenewStudentSession _renew;
  final RevokeStudentSession _revoke;
  MobileSession? _session;
  bool _running = false;

  bool get signedIn => _session != null;
  String? get accessToken => _session?.accessToken;

  Future<void> accept(MobileSession session) async {
    if (_running) throw StateError('Session action already in progress.');
    _running = true;
    try {
      // Do not consider a session established until encrypted persistence
      // succeeds; never downgrade to unencrypted storage on failure.
      await _vault.save(session);
      _session = session;
    } finally {
      _running = false;
    }
  }

  Future<bool> restore() async {
    if (_running) throw StateError('Session action already in progress.');
    _running = true;
    try {
      _session = null;
      final saved = await _vault.read();
      if (saved == null) return false;
      try {
        // Refresh validates the existing session against the server, instead
        // of trusting a potentially stale cached access token.
        final renewed = await _renew(saved.refreshToken);
        await _vault.save(renewed);
        _session = renewed;
        return true;
      } catch (_) {
        // Fail closed. Re-authentication is safer than stale privileges.
        await _vault.clear();
        return false;
      }
    } finally {
      _running = false;
    }
  }

  Future<void> refresh() async {
    if (_running) throw StateError('Session action already in progress.');
    final current = _session;
    if (current == null) throw StateError('No active student session.');
    _running = true;
    try {
      // The refresh token is single-use/rotated at the auth provider.
      final replacement = await _renew(current.refreshToken);
      await _vault.save(replacement);
      _session = replacement;
    } catch (_) {
      _session = null;
      await _vault.clear();
      rethrow;
    } finally {
      _running = false;
    }
  }

  Future<void> signOut() async {
    if (_running) throw StateError('Session action already in progress.');
    _running = true;
    try {
      final current = _session;
      _session = null;
      try {
        if (current != null) await _revoke(current.accessToken);
      } finally {
        // Local wipe always happens even if server revocation fails;
        // caller must surface a failed revoke, not claim global sign-out.
        await _vault.clear();
      }
    } finally {
      _running = false;
    }
  }
}
