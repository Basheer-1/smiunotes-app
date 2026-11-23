import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/student_recovery_page.dart';
import 'package:smiunotes_mobile/services/mobile_auth_api.dart';

class RecoveryFake extends MobileAuthApi {
  RecoveryFake({required this.enabled})
      : super(baseUrl: 'https://staging.example.org');

  final bool enabled;
  int sends = 0;
  int verifications = 0;
  String? requestedId, requestedEmail, usedCode, usedPassword;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<String> startOtp({
    required String studentId,
    String email = '',
    required String turnstileToken,
  }) async {
    expect(turnstileToken, 'mock-proof');
    sends++;
    requestedId = studentId;
    requestedEmail = email;
    return '00000000-0000-4000-8000-000000000001';
  }

  @override
  Future<MobileSession> verifyOtp({
    required String challenge,
    required String code,
    required String newPassword,
  }) async {
    expect(challenge, '00000000-0000-4000-8000-000000000001');
    verifications++;
    usedCode = code;
    usedPassword = newPassword;
    return const MobileSession(
      accessToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      refreshToken: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      verificationStatus: 'verified',
    );
  }
}

void main() {
  testWidgets('Disabled server never exposes password reset fields',
      (tester) async {
    final api = RecoveryFake(enabled: false);
    await tester.pumpWidget(MaterialApp(home: StudentRecoveryPage(
      api: api,
      challengeProvider: () async => 'mock-proof',
      onSession: (_) async {},
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recovery-disabled')), findsOneWidget);
    expect(find.byKey(const Key('recovery-id')), findsNothing);
    expect(api.sends, 0);
  });

  testWidgets('Student ID sends OTP to linked email, never typed email',
      (tester) async {
    final api = RecoveryFake(enabled: true);
    await tester.pumpWidget(MaterialApp(home: StudentRecoveryPage(
      api: api,
      challengeProvider: () async => 'mock-proof',
      onSession: (_) async {},
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recovery-email')), findsNothing);
    expect(find.byKey(const Key('recovery-details')), findsNothing);
    await tester.enterText(find.byKey(const Key('recovery-id')), 'csc-test-001');
    await tester.tap(find.byKey(const Key('recovery-submit')));
    await tester.pumpAndSettle();
    expect(api.sends, 1);
    expect(api.requestedId, 'CSC-TEST-001');
    expect(api.requestedEmail, '');
    expect(find.byKey(const Key('recovery-code')), findsOneWidget);
    expect(find.byKey(const Key('recovery-password')), findsOneWidget);
  });

  testWidgets('Valid OTP sets new password and hands session to coordinator',
      (tester) async {
    final api = RecoveryFake(enabled: true);
    MobileSession? received;
    await tester.pumpWidget(MaterialApp(home: StudentRecoveryPage(
      api: api,
      challengeProvider: () async => 'mock-proof',
      onSession: (session) async { received = session; },
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('recovery-id')), 'CSC-TEST-001');
    await tester.tap(find.byKey(const Key('recovery-submit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('recovery-code')), '123456');
    await tester.enterText(find.byKey(const Key('recovery-password')),
        'mynewpassword123');
    await tester.enterText(find.byKey(const Key('recovery-confirm-password')),
        'mynewpassword123');
    await tester.ensureVisible(find.byKey(const Key('recovery-submit')));
    await tester.tap(find.byKey(const Key('recovery-submit')));
    await tester.pumpAndSettle();
    expect(api.verifications, 1);
    expect(api.usedCode, '123456');
    expect(api.usedPassword, 'mynewpassword123');
    expect(received?.verificationStatus, 'verified');
    expect(find.byKey(const Key('recovery-completed')), findsOneWidget);
  });

  testWidgets('Missing CAPTCHA prevents OTP request',
      (tester) async {
    final api = RecoveryFake(enabled: true);
    await tester.pumpWidget(MaterialApp(home: StudentRecoveryPage(
      api: api,
      challengeProvider: () async => null,
      onSession: (_) async {},
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('recovery-id')), 'CSC-TEST-001');
    await tester.tap(find.byKey(const Key('recovery-submit')));
    await tester.pumpAndSettle();
    expect(api.sends, 0);
    expect(find.textContaining('security verification'), findsOneWidget);
  });

  testWidgets('Mismatch password blocks verification',
      (tester) async {
    final api = RecoveryFake(enabled: true);
    await tester.pumpWidget(MaterialApp(home: StudentRecoveryPage(
      api: api,
      challengeProvider: () async => 'mock-proof',
      onSession: (_) async {},
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('recovery-id')), 'CSC-TEST-001');
    await tester.tap(find.byKey(const Key('recovery-submit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('recovery-code')), '123456');
    await tester.enterText(find.byKey(const Key('recovery-password')),
        'mynewpassword123');
    await tester.enterText(find.byKey(const Key('recovery-confirm-password')),
        'mismatchedpassword123');
    await tester.ensureVisible(find.byKey(const Key('recovery-submit')));
    await tester.tap(find.byKey(const Key('recovery-submit')));
    await tester.pumpAndSettle();
    expect(api.verifications, 0);
  });
}
