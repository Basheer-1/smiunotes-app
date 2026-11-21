import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/services/mobile_auth_api.dart';
import 'package:smiunotes_mobile/services/secure_session_store.dart';
import 'package:smiunotes_mobile/services/student_session_controller.dart';

MobileSession session(String suffix) => MobileSession(
  accessToken: 'a' * 40 + suffix,
  refreshToken: 'r' * 40 + suffix,
  verificationStatus: 'verified',
);

class MemoryVault implements SessionVault {
  MobileSession? value;
  bool failSave = false;
  @override
  Future<void> save(MobileSession session) async {
    if (failSave) throw StateError('encrypted vault unavailable');
    value = session;
  }
  @override
  Future<MobileSession?> read() async => value;
  @override
  Future<void> clear() async => value = null;
}

void main() {
  test('new login only becomes signed in after secure write', () async {
    final vault = MemoryVault()..failSave = true;
    final controller = StudentSessionController(
      vault: vault,
      renew: (_) async => session('refreshed'),
      revoke: (_) async {},
    );
    await expectLater(controller.accept(session('one')), throwsStateError);
    expect(controller.signedIn, false);
    expect(vault.value, isNull);
  });

  test('restores only after server refresh and rotates stored credential', () async {
    final vault = MemoryVault()..value = session('old');
    var refreshCalls = 0;
    final controller = StudentSessionController(
      vault: vault,
      renew: (token) async {
        expect(token, contains('old'));
        refreshCalls++;
        return session('rotated');
      },
      revoke: (_) async {},
    );
    expect(await controller.restore(), true);
    expect(refreshCalls, 1);
    expect(controller.accessToken, session('rotated').accessToken);
    expect(vault.value?.refreshToken, session('rotated').refreshToken);
  });

  test('revoked session cannot survive application restore', () async {
    final vault = MemoryVault()..value = session('stale');
    final controller = StudentSessionController(
      vault: vault,
      renew: (_) async => throw StateError('revoked'),
      revoke: (_) async {},
    );
    expect(await controller.restore(), false);
    expect(controller.signedIn, false);
    expect(vault.value, isNull);
  });

  test('failed refresh clears stale access and refresh token', () async {
    final vault = MemoryVault();
    final controller = StudentSessionController(
      vault: vault,
      renew: (_) async => throw StateError('token reuse'),
      revoke: (_) async {},
    );
    await controller.accept(session('old'));
    await expectLater(controller.refresh(), throwsStateError);
    expect(controller.signedIn, false);
    expect(vault.value, isNull);
  });

  test('logout clears local vault even when server revocation fails', () async {
    final vault = MemoryVault();
    final controller = StudentSessionController(
      vault: vault,
      renew: (_) async => session('next'),
      revoke: (_) async => throw StateError('server unavailable'),
    );
    await controller.accept(session('old'));
    await expectLater(controller.signOut(), throwsStateError);
    expect(controller.signedIn, false);
    expect(vault.value, isNull);
  });
}
