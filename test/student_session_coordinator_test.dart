import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/models/student_profile.dart';
import 'package:smiunotes_mobile/services/mobile_auth_api.dart';
import 'package:smiunotes_mobile/services/secure_session_store.dart';
import 'package:smiunotes_mobile/services/student_session_controller.dart';
import 'package:smiunotes_mobile/services/student_session_coordinator.dart';

MobileSession testSession(String suffix) => MobileSession(
  accessToken: 'a' * 40 + suffix,
  refreshToken: 'b' * 40 + suffix,
  verificationStatus: 'verified',
);

const activeProfile = StudentProfile(
  studentName: 'Test Student',
  department: 'Computer Science',
  role: 'student',
  accountStatus: 'active',
  verificationStatus: 'verified',
);

class FakeVault implements SessionVault {
  MobileSession? saved;
  @override
  Future<void> save(MobileSession session) async => saved = session;
  @override
  Future<MobileSession?> read() async => saved;
  @override
  Future<void> clear() async => saved = null;
}

void main() {
  test('restored token is not treated as signed in before profile check',
      () async {
    final vault = FakeVault()..saved = testSession('old');
    final controller = StudentSessionController(
      vault: vault,
      renew: (_) async => testSession('rotated'),
      revoke: (_) async {},
    );
    final coordinator = StudentSessionCoordinator(
      controller: controller,
      loadProfile: (_) async => activeProfile,
    );
    expect(coordinator.authenticated, false);
    expect(await coordinator.restoreAndVerify(), true);
    expect(coordinator.authenticated, true);
    expect(coordinator.profile?.studentName, 'Test Student');
  });

  test('inactive account is logged out and removed from secure storage',
      () async {
    final vault = FakeVault();
    final controller = StudentSessionController(
      vault: vault,
      renew: (_) async => testSession('new'),
      revoke: (_) async {},
    );
    final coordinator = StudentSessionCoordinator(
      controller: controller,
      loadProfile: (_) async => const StudentProfile(
        studentName: 'Blocked Student',
        role: 'student',
        accountStatus: 'suspended',
        verificationStatus: 'rejected',
      ),
    );
    await expectLater(
      coordinator.acceptAndVerify(testSession('old')),
      throwsStateError,
    );
    expect(coordinator.authenticated, false);
    expect(controller.signedIn, false);
    expect(vault.saved, isNull);
  });

  test('failed profile fetch clears tokens even if server revoke fails',
      () async {
    final vault = FakeVault()..saved = testSession('old');
    final controller = StudentSessionController(
      vault: vault,
      renew: (_) async => testSession('new'),
      revoke: (_) async => throw StateError('offline revoke'),
    );
    final coordinator = StudentSessionCoordinator(
      controller: controller,
      loadProfile: (_) async => throw StateError('not authorized'),
    );
    expect(await coordinator.restoreAndVerify(), false);
    expect(vault.saved, isNull);
    expect(coordinator.authenticated, false);
  });

  test('sign out removes visible profile even if server is offline',
      () async {
    final vault = FakeVault();
    final controller = StudentSessionController(
      vault: vault,
      renew: (_) async => testSession('new'),
      revoke: (_) async => throw StateError('offline'),
    );
    final coordinator = StudentSessionCoordinator(
      controller: controller,
      loadProfile: (_) async => activeProfile,
    );
    await coordinator.acceptAndVerify(testSession('old'));
    expect(coordinator.authenticated, true);
    await expectLater(coordinator.signOut(), throwsStateError);
    expect(coordinator.profile, isNull);
    expect(vault.saved, isNull);
  });
}
