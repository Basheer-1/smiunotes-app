import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smiunotes_mobile/widgets/profile_avatar.dart';
import 'package:smiunotes_mobile/screens/native_information_pages.dart';
import 'package:smiunotes_mobile/services/external_link_opener.dart';
import 'package:smiunotes_mobile/models/student_profile.dart';

void main() {
  test('website-style avatar initials are deterministic', () {
    expect(ProfileAvatar.initials('Muhammad Basheer'), 'MB');
    expect(ProfileAvatar.initials('  Muhammad   Nul Basheer '), 'MN');
    expect(ProfileAvatar.initials('Single'), 'S');
    expect(ProfileAvatar.initials(''), '?');
  });

  test('Apply source URLs must be HTTPS with no embedded credentials', () {
    expect(ExternalLinkOpener.trustedHttps('https://example.org/apply'),
      isNotNull);
    expect(ExternalLinkOpener.trustedHttps('http://example.org/apply'),
      isNull);
    expect(ExternalLinkOpener.trustedHttps('javascript:alert(1)'),
      isNull);
    expect(ExternalLinkOpener.trustedHttps('https://name:secret@example.org/'),
      isNull);
    expect(ExternalLinkOpener.trustedHttps('not a URL'), isNull);
  });

  test('own-account avatar fields are optional and never require a URL', () {
    final profile = StudentProfile.fromJson({
      'student_name': 'Student', 'student_id': 'CSC-TEST-001',
      'department': 'Computer Science', 'role': 'admin',
      'account_status': 'active', 'verification_status': 'verified',
      'verified_email': 'example@example.org',
      'profile_id': '5a31ec52-dce0-48e4-a61d-8d0ca1ec7c53',
      'avatar_version': '1',
    });
    expect(profile.profileId, isNotNull);
    expect(profile.avatarVersion, '1');
    expect(profile.role, 'admin');
  });

  testWidgets('Contact and Support are real native screens with secure actions',
      (tester) async {
    for (final kind in ['contact', 'support']) {
      await tester.pumpWidget(MaterialApp(
        home: NativeInformationPage(key: ValueKey(kind), kind: kind),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(Key(kind == 'contact'
        ? 'native-contact-action' : 'native-support-action')), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    }
  });
}
