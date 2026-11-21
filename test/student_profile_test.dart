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
  testWidgets('Profile fetch happens once per rebuild, refresh is explicit',
      (tester) async {
    var calls = 0;
    Future<StudentProfile> load() async {
      calls++;
      return const StudentProfile(
        studentName: 'Cached Student',
        department: 'Computer Science',
        role: 'student',
        accountStatus: 'active',
        verificationStatus: 'verified',
      );
    }
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StudentProfilePage(profileLoader: load)),
    ));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Cached Student'), findsOneWidget);
    await tester.pump();
    expect(calls, 1);
    await tester.tap(find.byKey(const Key('profile-refresh')));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('Failed profile call displays retry and can recover',
      (tester) async {
    var calls = 0;
    Future<StudentProfile> load() async {
      calls++;
      if (calls == 1) throw StateError('offline');
      return const StudentProfile(
        studentName: 'Recovered Student',
        department: null,
        role: 'student',
        accountStatus: 'active',
        verificationStatus: 'unverified',
      );
    }
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StudentProfilePage(profileLoader: load)),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-retry')), findsOneWidget);
    expect(calls, 1);
    await tester.tap(find.byKey(const Key('profile-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Recovered Student'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('Inactive profile hides own account identity', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StudentProfilePage(
        profileLoader: () async => const StudentProfile(
          studentName: 'Must Not Display',
          studentId: 'CSC-INACTIVE-001',
          department: 'Computer Science',
          role: 'student',
          accountStatus: 'suspended',
          verificationStatus: 'verified',
        ),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inactive-profile')), findsOneWidget);
    expect(find.text('Must Not Display'), findsNothing);
    expect(find.textContaining('CSC-INACTIVE-001'), findsNothing);
  });

}
