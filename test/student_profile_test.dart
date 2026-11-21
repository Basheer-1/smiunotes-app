import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/models/student_profile.dart';
import 'package:smiunotes_mobile/screens/student_profile_page.dart';

void main() {
  test('Own-account model validates student name', () {
    expect(
      () => StudentProfile.fromJson({'student_name': ''}),
      throwsFormatException,
    );
    final profile = StudentProfile.fromJson({
      'student_name': 'QA Student',
      'student_id': 'CSC-TEST',
      'department': 'Computer Science',
      'role': 'student',
      'account_status': 'active',
      'verification_status': 'verified',
    });
    expect(profile.studentId, 'CSC-TEST');
    expect(profile.verificationStatus, 'verified');
  });

  testWidgets('Profile is logged out until secure mobile login exists',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StudentProfilePage()),
    ));
    expect(find.text('Student sign-in is coming soon'), findsOneWidget);
  });

  testWidgets('Own profile renders after authenticated loader succeeds',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StudentProfilePage(
          profileLoader: () async => const StudentProfile(
            studentName: 'QA Student',
            studentId: 'CSC-TEST',
            department: 'Computer Science',
            role: 'student',
            accountStatus: 'active',
            verificationStatus: 'verified',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('QA Student'), findsOneWidget);
    expect(find.text('Verification: verified'), findsOneWidget);
  });
}
