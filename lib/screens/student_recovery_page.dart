import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../services/mobile_auth_api.dart';
import 'student_login_page.dart';

/// Student App password reset matches the website:
/// Student ID -> existing linked-email OTP -> new password -> signed-in session.
/// Manual recovery for lost email/contested claims remains on the website.
class StudentRecoveryPage extends StatefulWidget {
  const StudentRecoveryPage({
    super.key,
    required this.api,
    required this.challengeProvider,
    required this.onSession,
  });

  final MobileAuthApi api;
  final ChallengeProvider challengeProvider;
  final SessionReceiver onSession;

  @override
  State<StudentRecoveryPage> createState() => _StudentRecoveryPageState();
}

class _StudentRecoveryPageState extends State<StudentRecoveryPage> {
  final form = GlobalKey<FormState>();
  final studentId = TextEditingController();
  final code = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  late final Future<bool> availability = widget.api.isEnabled();
  String? challenge, error;
  bool working = false, completed = false, reveal = false;

  @override
  void dispose() {
    studentId.dispose();
    code.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (working || !form.currentState!.validate()) return;
    if (challenge != null && newPassword.text != confirmPassword.text) {
      setState(() => error = 'Passwords do not match.');
      return;
    }
    setState(() { working = true; error = null; });
    try {
      if (!await widget.api.isEnabled()) {
        throw const HttpException('Verification temporarily unavailable.');
      }
      if (challenge == null) {
        final proof = await widget.challengeProvider();
        if (proof == null || proof.isEmpty) {
          if (mounted) setState(() =>
            error = 'Complete the security verification to continue.');
          return;
        }
        final pending = await widget.api.startOtp(
          studentId: studentId.text.trim().toUpperCase(),
          // No email field: server chooses the existing linked mailbox.
          email: '',
          turnstileToken: proof,
        );
        if (mounted) setState(() => challenge = pending);
      } else {
        final session = await widget.api.verifyOtp(
          challenge: challenge!,
          code: code.text.trim(),
          newPassword: newPassword.text,
        );
        // Website OTP reset also signs the student in. Reuse the app's
        // encrypted-session receiver instead of creating an orphan Auth slot.
        await widget.onSession(session);
        if (mounted) {
          newPassword.clear();
          confirmPassword.clear();
          code.clear();
          setState(() => completed = true);
        }
      }
    } on HttpException catch (e) {
      const safe = {
        'Security verification required.',
        'Invalid verification request.',
        'Verification unavailable.',
        'Unable to set account password.',
        'Maximum device limit reached.',
      };
      if (mounted) {
        setState(() => error = safe.contains(e.message)
          ? e.message
          : 'Verification could not be completed. Retry or request a new code.');
      }
    } on FormatException {
      if (mounted) setState(() =>
        error = 'Check your Student ID, verification code and new password.');
    } catch (_) {
      if (mounted) setState(() =>
        error = 'Password reset is temporarily unavailable. Please retry.');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void restart() => setState(() {
    challenge = null;
    error = null;
    code.clear();
    newPassword.clear();
    confirmPassword.clear();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
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
              'Mobile password reset is unavailable. Use smiunotes.com to reset your password.',
              key: Key('recovery-disabled'),
              textAlign: TextAlign.center,
            ),
          ));
        }
        if (completed) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_outlined, size: 54),
              const SizedBox(height: 16),
              const Text('Password updated',
                key: Key('recovery-completed'),
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text('Your linked email has been verified and your new password saved.',
                textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue to SMIUNotes')),
            ]),
          ));
        }
        return Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(challenge == null ? Icons.lock_reset_outlined
                : Icons.mark_email_read_outlined, size: 43,
                color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text(challenge == null
                  ? 'Reset your password' : 'Verify your email',
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(challenge == null
                ? 'Enter your Student ID. We will send a verification code '
                  'only to the email already linked to your account.'
                : 'Enter the 6-digit code sent to your linked email, then '
                  'set a new password.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              if (challenge == null)
                TextFormField(
                  key: const Key('recovery-id'),
                  controller: studentId,
                  enabled: !working,
                  maxLength: 32,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Student ID'),
                  validator: (value) => RegExp(
                    r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$')
                      .hasMatch((value ?? '').trim())
                    ? null : 'Enter a valid Student ID',
                )
              else ...[
                TextFormField(
                  key: const Key('recovery-code'),
                  controller: code,
                  enabled: !working,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '6-digit code'),
                  validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim())
                      ? null : 'Enter the 6-digit code',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('recovery-password'),
                  controller: newPassword,
                  enabled: !working,
                  obscureText: !reveal,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => reveal = !reveal),
                      icon: Icon(reveal ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    ),
                  ),
                  validator: (v) => (v?.length ?? 0) >= 12 &&
                      (v?.length ?? 0) <= 128
                      ? null : 'Use 12–128 characters',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('recovery-confirm-password'),
                  controller: confirmPassword,
                  enabled: !working,
                  obscureText: !reveal,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password'),
                  validator: (v) => v == newPassword.text
                      ? null : 'Passwords do not match',
                ),
              ],
              if (error != null) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!, key: const Key('recovery-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('recovery-submit'),
                onPressed: working ? null : submit,
                icon: Icon(challenge == null
                  ? Icons.mark_email_unread_outlined : Icons.verified_user_outlined),
                label: Text(working ? 'Please wait…' : challenge == null
                  ? 'Send verification code' : 'Verify code and reset password'),
              ),
              if (working) const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator()),
              if (challenge != null) TextButton(
                key: const Key('recovery-restart'),
                onPressed: working ? null : restart,
                child: const Text('Request a new code'),
              ),
              const SizedBox(height: 12),
              Text(
                'If you no longer have access to your linked email, '
                'please contact SMIUNotes support for a private review.',
                style: TextStyle(fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        );
      },
    ),
  );
}
