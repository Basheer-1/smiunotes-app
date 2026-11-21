import 'package:material_ui/material_ui.dart';

import '../models/student_profile.dart';
import '../services/mobile_auth_api.dart';
import 'student_login_page.dart';

/// Staging-only account experience; NOT constructed by the default app.
/// A login is visible only after encrypted storage and live profile validation.
class StudentAccountGateway extends StatefulWidget {
  const StudentAccountGateway({
    super.key,
    required this.api,
    required this.challengeProvider,
    required this.acceptAndVerify,
    required this.restoreAndVerify,
    required this.loadValidatedProfile,
    required this.signOut,
  });

  final MobileAuthApi api;
  final ChallengeProvider challengeProvider;
  final Future<void> Function(MobileSession) acceptAndVerify;
  final Future<bool> Function() restoreAndVerify;
  final StudentProfile? Function() loadValidatedProfile;
  final Future<void> Function() signOut;

  @override
  State<StudentAccountGateway> createState() => _StudentAccountGatewayState();
}

class _StudentAccountGatewayState extends State<StudentAccountGateway> {
  late Future<bool> _restoring;
  StudentProfile? _profile;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoring = _restore();
  }

  Future<bool> _restore() async {
    try {
      final restored = await widget.restoreAndVerify();
      if (!mounted) return false;
      setState(() => _profile = restored ? widget.loadValidatedProfile() : null);
      return restored;
    } catch (_) {
      if (mounted) setState(() => _profile = null);
      return false;
    }
  }

  Future<void> _onSession(MobileSession session) async {
    await widget.acceptAndVerify(session);
    if (!mounted) return;
    final profile = widget.loadValidatedProfile();
    if (profile == null || profile.accountStatus != 'active') {
      throw StateError('Account validation failed.');
    }
    setState(() {
      _profile = profile;
      _error = null;
    });
    Navigator.of(context).pop();
  }

  Future<void> _logout() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _profile = null;
    });
    try {
      await widget.signOut();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Local account cleared. Server logout could not be confirmed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openLogin() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StudentLoginPage(
        api: widget.api,
        challengeProvider: widget.challengeProvider,
        onSession: _onSession,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _restoring,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        key: const Key('account-gateway'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          const Text('Student account', style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w900,
            color: Color(0xFF102B4B),
          )),
          const SizedBox(height: 18),
          if (_error != null)
            Text(_error!, key: const Key('account-error')),
          if (_profile == null) ...[
            const Text('Sign in to view your verified student profile.'),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('account-open-login'),
              onPressed: _busy ? null : _openLogin,
              icon: const Icon(Icons.login),
              label: const Text('Student sign-in'),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_profile!.studentName,
                      style: const TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (_profile!.studentId != null)
                      Text('Student ID: ' + _profile!.studentId!),
                    if (_profile!.department != null)
                      Text('Department: ' + _profile!.department!),
                    Text('Verification: ' + _profile!.verificationStatus),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('account-signout'),
                      onPressed: _busy ? null : _logout,
                      icon: const Icon(Icons.logout),
                      label: Text(_busy ? 'Signing out…' : 'Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}
