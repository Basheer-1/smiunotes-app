import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/models/student_profile.dart';
import 'package:smiunotes_mobile/screens/secure_website_form_page.dart';
import 'package:smiunotes_mobile/screens/student_verification_status_page.dart';

void main() {
  testWidgets('only allowlisted SMIUNotes forms can be opened',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SecureWebsiteFormPage(
        path: '/untrusted-route',
        title: 'Unsupported',
      ),
    ));
    expect(find.text('Unsupported SMIUNotes page.'), findsOneWidget);
  });

  testWidgets('verified student sees validated status without upload prompt',
      (tester) async {
    const profile = StudentProfile(
      studentName: 'Sample Student',
      studentId: 'CSC-26F-001',
      department: 'CS',
      role: 'student',
      accountStatus: 'active',
      verificationStatus: 'verified',
    );
    await tester.pumpWidget(const MaterialApp(
      home: StudentVerificationStatusPage(profile: profile),
    ));
    expect(find.text('Student identity verified'), findsOneWidget);
    expect(find.byKey(const Key('verification-website-action')), findsNothing);
  });
}
