import '../models/student_profile.dart';
import 'mobile_auth_api.dart';
import 'student_session_controller.dart';

typedef LoadMyProfile = Future<StudentProfile> Function(String accessToken);

/// The only bridge between a credential-bearing session and profile UI.
/// Validation is always performed by the server. This class is NOT wired to
/// app startup until staging auth and challenge verification are approved.
class StudentSessionCoordinator {
  factory StudentSessionCoordinator({
    required StudentSessionController controller,
    required LoadMyProfile loadProfile,
  }) => StudentSessionCoordinator._(controller, loadProfile);

  StudentSessionCoordinator._(this._controller, this._loadProfile);

  final StudentSessionController _controller;
  final LoadMyProfile _loadProfile;

  StudentProfile? _profile;
  bool _running = false;

  StudentProfile? get profile => _profile;
  bool get authenticated => _controller.signedIn && _profile != null;

  Future<bool> restoreAndVerify() async {
    if (_running) throw StateError('Session operation already in progress.');
    _running = true;
    try {
      _profile = null;
      final restored = await _controller.restore();
      if (!restored) return false;
      return await _verifyOrInvalidate();
    } finally {
      _running = false;
    }
  }

  Future<void> acceptAndVerify(MobileSession session) async {
    if (_running) throw StateError('Session operation already in progress.');
    _running = true;
    try {
      _profile = null;
      await _controller.accept(session);
      if (!await _verifyOrInvalidate()) {
        throw StateError('Account validation failed.');
      }
    } finally {
      _running = false;
    }
  }

  Future<bool> renewAndVerify() async {
    if (_running) throw StateError('Session operation already in progress.');
    _running = true;
    try {
      _profile = null;
      try {
        await _controller.refresh();
      } catch (_) {
        return false;
      }
      return await _verifyOrInvalidate();
    } finally {
      _running = false;
    }
  }

  Future<bool> _verifyOrInvalidate() async {
    final token = _controller.accessToken;
    if (token == null) return false;
    try {
      final profile = await _loadProfile(token);
      if (profile.accountStatus != 'active') {
        throw const FormatException('Student access is not active.');
      }
      _profile = profile;
      return true;
    } catch (_) {
      _profile = null;
      // Never leave a locally usable token after account validation fails.
      // The controller guarantees local wipe even on revocation errors.
      try {
        await _controller.signOut();
      } catch (_) {
        // Server revocation may be unavailable. Local access is still wiped.
      }
      return false;
    }
  }

  Future<void> signOut() async {
    if (_running) throw StateError('Session operation already in progress.');
    _running = true;
    try {
      _profile = null;
      await _controller.signOut();
    } finally {
      _running = false;
    }
  }
}
