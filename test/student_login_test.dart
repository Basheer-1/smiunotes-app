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
}
