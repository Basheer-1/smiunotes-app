import 'secure_session_store.dart';
import 'student_profile_api.dart';
import 'student_session_api.dart';
import 'student_session_controller.dart';
import 'student_session_coordinator.dart';

/// Dependency composition for a future, explicitly approved login activation.
/// Constructing this object does NOT read tokens, restore a session, or make
/// a network request. The default app does not create this runtime.
class StudentAuthRuntime {
  const StudentAuthRuntime._({
    required this.sessionApi,
    required this.profileApi,
    required this.controller,
    required this.coordinator,
  });

  final StudentSessionApi sessionApi;
  final StudentProfileApi profileApi;
  final StudentSessionController controller;
  final StudentSessionCoordinator coordinator;

  factory StudentAuthRuntime.forStaging({
    required String httpsBaseUrl,
    SessionVault? vault,
  }) {
    final uri = Uri.tryParse(httpsBaseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw const FormatException('Use an approved HTTPS staging origin.');
    }
    final sessions = StudentSessionApi(baseUrl: httpsBaseUrl);
    final profiles = StudentProfileApi(baseUrl: httpsBaseUrl);
    final sessionController = StudentSessionController(
      vault: vault ?? const SecureSessionStore(),
      renew: sessions.renew,
      revoke: sessions.revoke,
    );
    return StudentAuthRuntime._(
      sessionApi: sessions,
      profileApi: profiles,
      controller: sessionController,
      coordinator: StudentSessionCoordinator(
        controller: sessionController,
        loadProfile: profiles.fetchOwnProfile,
      ),
    );
  }
}
