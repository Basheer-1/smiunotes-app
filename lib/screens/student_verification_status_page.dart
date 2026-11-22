import 'package:material_ui/material_ui.dart';
import '../models/student_profile.dart';
import 'secure_website_form_page.dart';

/// Native status view. Does not upload identity documents or bypass the
/// website's existing authenticated verification workflow.
class StudentVerificationStatusPage extends StatelessWidget {
  const StudentVerificationStatusPage({super.key, required this.profile});
  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final status = profile.verificationStatus.toLowerCase();
    final verified = status == 'verified';
    return Scaffold(
      appBar: AppBar(title: const Text('Student verification')),
      body: ListView(
        key: const Key('native-verification-status'),
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(verified ? Icons.verified_user_rounded
                    : Icons.pending_actions_outlined, size: 36),
                  const SizedBox(height: 14),
                  Text(verified ? 'Student identity verified'
                    : 'Verification status: ${profile.verificationStatus}',
                    style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Text('Student ID: ${profile.studentId ?? 'Unavailable'}'),
                  const SizedBox(height: 10),
                  Text(verified
                    ? 'Your student verification is recorded on SMIUNotes.'
                    : 'Your current status is shown directly from your '
                      'validated account. If additional evidence is requested, '
                      'complete it through the secure website workflow.'),
                ],
              ),
            ),
          ),
          if (!verified) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('verification-website-action'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SecureWebsiteFormPage(
                    path: '/profile',
                    title: 'Account verification',
                  ),
                ),
              ),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Open account verification'),
            ),
            const SizedBox(height: 8),
            const Text('The website may ask you to sign in separately. '
              'No student-card images are stored by this screen.',
              textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
