import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/student_recovery_page.dart';
import 'package:smiunotes_mobile/services/mobile_auth_api.dart';

class RecoveryFake extends MobileAuthApi {
  RecoveryFake({required this.enabled})
      : super(baseUrl: 'https://staging.example.org');
  final bool enabled;
  int calls = 0;
  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Future<void> requestRecovery({
    required String studentId,
    required String email,
    required String details,
    required String turnstileToken,
  }) async {
    expect(studentId, 'CSC-TEST-001');
    expect(turnstileToken, 'mock-proof');
    calls++;
  }
}

void main() {
  testWidgets('Disabled server never displays recovery input fields',
      (tester) async {
    final api = RecoveryFake(enabled: false);
    await tester.pumpWidget(MaterialApp(home: StudentRecoveryPage(
      api: api,
      challengeProvider: () async => 'mock-proof',
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recovery-disabled')), findsOneWidget);
    expect(find.byKey(const Key('recovery-email')), findsNothing);
    expect(api.calls, 0);
  });

  testWidgets('Enabled recovery submits only after proof is provided',
      (tester) async {
    final api = RecoveryFake(enabled: true);
    await tester.pumpWidget(MaterialApp(home: StudentRecoveryPage(
      api: api,
      challengeProvider: () async => 'mock-proof',
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('recovery-id')), 'CSC-TEST-001');
    await tester.enterText(find.byKey(const Key('recovery-email')), 'qa@example.org');
    await tester.enterText(find.byKey(const Key('recovery-details')),
        'I cannot access my account');
    await tester.ensureVisible(find.byKey(const Key('recovery-submit')));
    await tester.tap(find.byKey(const Key('recovery-submit')));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(find.byKey(const Key('recovery-submitted')), findsOneWidget);
  });

  testWidgets('Missing CAPTCHA blocks recovery request', (tester) async {
    final api = RecoveryFake(enabled: true);
    await tester.pumpWidget(MaterialApp(home: StudentRecoveryPage(
      api: api,
      challengeProvider: () async => null,
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('recovery-id')), 'CSC-TEST-001');
    await tester.enterText(find.byKey(const Key('recovery-email')), 'qa@example.org');
    await tester.enterText(find.byKey(const Key('recovery-details')),
        'Please help with my account');
    await tester.ensureVisible(find.byKey(const Key('recovery-submit')));
    await tester.tap(find.byKey(const Key('recovery-submit')));
    await tester.pumpAndSettle();
    expect(api.calls, 0);
    expect(find.byKey(const Key('account-error')), findsNothing);
    expect(find.textContaining('Recovery request unavailable'), findsOneWidget);
  });
}
