import 'package:material_ui/material_ui.dart';

import '../models/student_profile.dart';
import '../services/mobile_auth_api.dart';
import 'student_login_page.dart';

/// Profile is read-only and never owns credentials. The real student-session
/// runtime is injected only after staging auth has passed its security gate.
class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key, this.profileLoader});
  final Future<StudentProfile> Function()? profileLoader;

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  Future<StudentProfile>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StudentProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileLoader != widget.profileLoader) _load();
  }

  void _load() {
    // Future is created once, never on every rebuild. There is no implicit
    // credential refresh or sensitive profile request on a widget rebuild.
    final load = widget.profileLoader;
    _profile = load == null ? null : Future<StudentProfile>.sync(load);
  }

  void _retry() {
    setState(_load);
  }

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
      if (_profile == null) ...[
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
        )),
        const _LoginPreviewButton(),
      ] else
        FutureBuilder<StudentProfile>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Card(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Unable to load your account. Sign in again.'),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('profile-retry'),
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry profile'),
                    ),
                  ],
                ),
              ));
            }
            final profile = snapshot.data!;
            if (profile.accountStatus != 'active') {
              return const Card(child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Student account is not active. Profile details are unavailable.',
                  key: Key('inactive-profile'),
                ),
              ));
            }
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
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('profile-refresh'),
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ));
          },
        ),
    ],
  );
}

class _LoginPreviewButton extends StatelessWidget {
  const _LoginPreviewButton();

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('open-login-preview'),
    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const StudentLoginPage(
        api: MobileAuthApi(
          baseUrl: String.fromEnvironment('SMIUNOTES_API_BASE', defaultValue: ''),
        ),
      ),
    )),
    icon: const Icon(Icons.login),
    label: const Text('View mobile sign-in status'),
  );
}
