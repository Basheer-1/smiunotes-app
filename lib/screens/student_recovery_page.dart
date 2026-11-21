import 'package:material_ui/material_ui.dart';
import '../services/mobile_auth_api.dart';
import 'student_login_page.dart';

/// Staging-only recovery: always requires a server-enabled mobile-auth
/// capability and a trusted Turnstile proof provider.
class StudentRecoveryPage extends StatefulWidget {
  const StudentRecoveryPage({
    super.key,
    required this.api,
    required this.challengeProvider,
  });

  final MobileAuthApi api;
  final ChallengeProvider challengeProvider;

  @override
  State<StudentRecoveryPage> createState() => _StudentRecoveryPageState();
}

class _StudentRecoveryPageState extends State<StudentRecoveryPage> {
  final form = GlobalKey<FormState>();
  final studentId = TextEditingController();
  final email = TextEditingController();
  final details = TextEditingController();
  late final Future<bool> availability = widget.api.isEnabled();
  bool working = false, submitted = false;
  String? error;

  @override
  void dispose() {
    studentId.dispose();
    email.dispose();
    details.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (working || !form.currentState!.validate()) return;
    setState(() { working = true; error = null; });
    try {
      if (!await widget.api.isEnabled()) {
        throw StateError('Mobile account recovery unavailable');
      }
      final proof = await widget.challengeProvider();
      if (proof == null || proof.isEmpty) {
        throw StateError('Security verification required');
      }
      await widget.api.requestRecovery(
        studentId: studentId.text,
        email: email.text,
        details: details.text,
        turnstileToken: proof,
      );
      if (mounted) setState(() => submitted = true);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Recovery request unavailable. Please retry.');
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account recovery')),
    body: FutureBuilder<bool>(
      future: availability,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data != true) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Mobile recovery is not enabled. Use the website account recovery.',
              key: Key('recovery-disabled'),
              textAlign: TextAlign.center,
            ),
          ));
        }
        if (submitted) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'If eligible, our team will review your request. '
              'No account details have been changed.',
              key: Key('recovery-submitted'),
              textAlign: TextAlign.center,
            ),
          ));
        }
        return Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Recover your account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('recovery-id'),
                controller: studentId,
                maxLength: 32,
                decoration: const InputDecoration(labelText: 'Student ID'),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Enter your Student ID' : null,
              ),
              TextFormField(
                key: const Key('recovery-email'),
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Contact email'),
                validator: (v) => (v ?? '').contains('@')
                    ? null : 'Enter a valid email',
              ),
              TextFormField(
                key: const Key('recovery-details'),
                controller: details,
                maxLength: 2000,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Explain what happened',
                ),
                validator: (v) => (v ?? '').trim().length >= 10
                    ? null : 'Please provide at least 10 characters',
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('recovery-submit'),
                onPressed: working ? null : submit,
                child: Text(working ? 'Submitting…' : 'Request account recovery'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
