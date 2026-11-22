import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/models/student_profile.dart';
import 'package:smiunotes_mobile/screens/native_profile_settings_page.dart';
import 'package:smiunotes_mobile/services/mobile_auth_api.dart';

void main() {
  const profile = StudentProfile(
    studentName: 'Test Student',
    studentId: 'CSC-26F-001',
    department: 'Computer Science',
    verifiedEmail: 'student@example.com',
    role: 'student',
    accountStatus: 'active',
    verificationStatus: 'verified',
  );

  testWidgets('native settings shows only validated account details',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NativeProfileSettingsPage(
        profile: profile,
        api: const MobileAuthApi(baseUrl: 'https://example.com'),
        challengeProvider: () async => null,
        darkMode: false,
        onThemeChanged: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Test Student'), findsNWidgets(2));
    expect(find.text('student@example.com'), findsOneWidget);
    expect(find.text('Computer Science'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-account-recovery')), 250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('settings-account-recovery')), findsOneWidget);
    expect(find.byKey(const Key('settings-push')), findsNothing);
  });

  testWidgets('theme toggle updates locally and notifies parent',
      (tester) async {
    bool? selected;
    await tester.pumpWidget(MaterialApp(
      home: NativeProfileSettingsPage(
        profile: profile,
        api: const MobileAuthApi(baseUrl: 'https://example.com'),
        challengeProvider: () async => null,
        darkMode: false,
        onThemeChanged: (value) => selected = value,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-theme')), 250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings-theme')));
    await tester.pump();
    expect(selected, isTrue);
    expect(tester.widget<SwitchListTile>(
      find.byKey(const Key('settings-theme'))).value, isTrue);
  });
}
