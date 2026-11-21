import 'package:material_ui/material_ui.dart';
import '../models/student_profile.dart';

/// Profile rendering only. Login and token storage are deliberately excluded.
class StudentProfilePage extends StatelessWidget {
  const StudentProfilePage({super.key, this.profileLoader});
  final Future<StudentProfile> Function()? profileLoader;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('student-profile-page'),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 116),
    children: [
      const Text('My profile', style: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF102B4B))),
      const SizedBox(height: 10),
      const Text('Your SMIUNotes student identity and verification status.'),
      const SizedBox(height: 20),
      if (profileLoader == null)
        const Card(child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 34, color: Color(0xFF183C68)),
              SizedBox(height: 14),
              Text('Student sign-in is coming soon', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              Text('Native Student ID authentication is not enabled yet. '
                'Use the SMIUNotes website for account actions. '
                'No credentials are stored in this preview.'),
            ],
          ),
        ))
      else
        FutureBuilder<StudentProfile>(
          future: profileLoader!(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Card(child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Unable to load your account. Sign in again.'),
              ));
            }
            final profile = snapshot.data!;
            return Card(child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.studentName,
                    style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  if (profile.studentId != null)
                    Text('Student ID: ${profile.studentId}'),
                  if (profile.department != null)
                    Text('Department: ${profile.department}'),
                  Text('Role: ${profile.role}'),
                  Text('Account: ${profile.accountStatus}'),
                  Text('Verification: ${profile.verificationStatus}'),
                  if (profile.verifiedEmail != null)
                    Text('Email: ${profile.verifiedEmail}'),
                ],
              ),
            ));
          },
        ),
    ],
  );
}
