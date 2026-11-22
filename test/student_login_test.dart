import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/student_login_page.dart';
import 'package:smiunotes_mobile/services/mobile_auth_api.dart';

class FakeDisabledAuth extends MobileAuthApi {
  const FakeDisabledAuth() : super(baseUrl: 'https://staging.example.com');
  @override
  Future<bool> isEnabled() async => false;
}

class FakeEnabledAuth extends MobileAuthApi {
  const FakeEnabledAuth() : super(baseUrl: 'https://staging.example.com');
  @override
  Future<bool> isEnabled() async => true;
}


class FakeLoginAuth extends MobileAuthApi {
  FakeLoginAuth() : super(baseUrl: 'https://staging.example.com');
  String? submittedStudentId;
  int passwordCalls = 0;

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<MobileSession> passwordLogin({
    required String studentId,
    required String password,
    required String turnstileToken,
  }) async {
    passwordCalls++;
    submittedStudentId = studentId;
    if (turnstileToken != 'mock-proof') throw StateError('Missing proof');
    return const MobileSession(
      accessToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      refreshToken: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      verificationStatus: 'verified',
    );
  }
}

void main() {
  testWidgets('Server-disabled login never shows credential fields',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home:
      StudentLoginPage(api: FakeDisabledAuth())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-disabled')), findsOneWidget);
    expect(find.byKey(const Key('student-id')), findsNothing);
    expect(find.byKey(const Key('password')), findsNothing);
    expect(find.byKey(const Key('login-submit')), findsNothing);
  });

  testWidgets('Even server-enabled login remains blocked without security hooks',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home:
      StudentLoginPage(api: FakeEnabledAuth())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-disabled')), findsOneWidget);
    expect(find.byKey(const Key('password')), findsNothing);
  });
  testWidgets('website-style registration asks for email and matching password',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StudentLoginPage(
        api: const FakeEnabledAuth(),
        challengeProvider: () async => 'mock-proof',
        onSession: (_) async {},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-mode-register')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('email')), findsOneWidget);
    expect(find.byKey(const Key('new-password')), findsOneWidget);
    expect(find.byKey(const Key('confirm-password')), findsOneWidget);
    expect(find.byKey(const Key('otp-code')), findsNothing);
    await tester.tap(find.byKey(const Key('login-mode-signin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('password')), findsOneWidget);
  });

  testWidgets('Enabled mock login sends proof and hands session to receiver',
      (tester) async {
    final api = FakeLoginAuth();
    MobileSession? delivered;
    await tester.pumpWidget(MaterialApp(
      home: StudentLoginPage(
        api: api,
        challengeProvider: () async => 'mock-proof',
        onSession: (session) async { delivered = session; },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-disabled')), findsNothing);
    await tester.enterText(find.byKey(const Key('student-id')), 'csc-test-001');
    await tester.enterText(find.byKey(const Key('password')), 'test-password');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(api.submittedStudentId, 'CSC-TEST-001');
    expect(api.passwordCalls, 1);
    expect(delivered?.verificationStatus, 'verified');
  });

}
