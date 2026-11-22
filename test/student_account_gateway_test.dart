import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/models/student_profile.dart';
import 'package:smiunotes_mobile/screens/student_account_gateway.dart';
import 'package:smiunotes_mobile/services/mobile_auth_api.dart';

class FakeGatewayApi extends MobileAuthApi {
  const FakeGatewayApi() : super(baseUrl: 'https://staging.example.org');

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<MobileSession> passwordLogin({
    required String studentId,
    required String password,
    required String turnstileToken,
  }) async {
    if (studentId != 'CSC-TEST-001' || turnstileToken != 'mock-proof') {
      throw StateError('Invalid test request');
    }
    return const MobileSession(
      accessToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      refreshToken: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      verificationStatus: 'verified',
    );
  }
}

const profile = StudentProfile(
  studentName: 'QA Student',
  studentId: 'CSC-TEST-001',
  department: 'Computer Science',
  role: 'student',
  accountStatus: 'active',
  verificationStatus: 'verified',
);

void main() {
  testWidgets('Staging gateway accepts only verified mock login, then signs out',
      (tester) async {
    StudentProfile? current;
    var accepted = 0;
    var revoked = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StudentAccountGateway(
        api: const FakeGatewayApi(),
        challengeProvider: () async => 'mock-proof',
        acceptAndVerify: (session) async {
          accepted++;
          current = profile; // Pretend secure vault and server checks passed.
        },
        restoreAndVerify: () async => false,
        loadValidatedProfile: () => current,
        signOut: () async {
          current = null;
          revoked++;
        },
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-open-login')), findsOneWidget);
    expect(find.text('QA Student'), findsNothing);

    await tester.tap(find.byKey(const Key('account-open-login')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('student-id')), 'csc-test-001');
    await tester.enterText(find.byKey(const Key('password')), 'test-password');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(accepted, 1);
    expect(find.text('QA Student'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('account-signout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-signout')));
    await tester.pumpAndSettle();
    expect(revoked, 1);
    expect(find.text('QA Student'), findsNothing);
    expect(find.byKey(const Key('account-open-login')), findsOneWidget);
  });

  testWidgets('Session restore cannot show an account without a valid profile',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StudentAccountGateway(
        api: const FakeGatewayApi(),
        challengeProvider: () async => 'mock-proof',
        acceptAndVerify: (_) async {},
        restoreAndVerify: () async => false,
        loadValidatedProfile: () => null,
        signOut: () async {},
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('QA Student'), findsNothing);
    expect(find.byKey(const Key('account-open-login')), findsOneWidget);
  });
  testWidgets('Protected actions appear only for a verified Student Card',
      (tester) async {
    for (final status in ['provisional', 'verified']) {
      final candidate = StudentProfile(
        studentName: 'QA Student',
        studentId: 'CSC-TEST-001',
        department: 'Computer Science',
        role: 'student',
        accountStatus: 'active',
        verificationStatus: status,
      );
      await tester.pumpWidget(MaterialApp(
        key: ValueKey(status),
        home: Scaffold(body: StudentAccountGateway(
          api: const FakeGatewayApi(),
          challengeProvider: () async => 'mock-proof',
          acceptAndVerify: (_) async {},
          restoreAndVerify: () async => true,
          loadValidatedProfile: () => candidate,
          signOut: () async {},
          onCreateDiscussion: () {},
          onOpenVerifiedNote: () {},
        )),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-create-discussion')),
        status == 'verified' ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('account-open-verified-note')),
        status == 'verified' ? findsOneWidget : findsNothing);
    }
  });

}
