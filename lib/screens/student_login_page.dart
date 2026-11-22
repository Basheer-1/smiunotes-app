import 'dart:io';
import 'student_recovery_page.dart';
import 'package:material_ui/material_ui.dart';
import '../services/mobile_auth_api.dart';

typedef ChallengeProvider = Future<String?> Function();
typedef SessionReceiver = Future<void> Function(MobileSession session);

/// Native login presentation. Password/OTP requests are blocked unless:
/// 1) staging server explicitly enables mobile auth, 2) a trusted Turnstile
/// callback exists, AND 3) a secure session receiver is configured.
/// The default app injects none of these privileged capabilities.
class StudentLoginPage extends StatefulWidget {
  const StudentLoginPage({
    super.key,
    required this.api,
    this.challengeProvider,
    this.onSession,
  });
  final MobileAuthApi api;
  final ChallengeProvider? challengeProvider;
  final SessionReceiver? onSession;

  @override
  State<StudentLoginPage> createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage> {
  final form = GlobalKey<FormState>();
  final studentId = TextEditingController();
  final password = TextEditingController();
  final email = TextEditingController();
  final code = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  late Future<bool> availability;
  String? challenge, error;
  bool registration = false, busy = false, revealPassword = false;

  @override
  void initState() {
    super.initState();
    availability = widget.api.isEnabled();
  }

  @override
  void dispose() {
    studentId.dispose();
    password.dispose();
    email.dispose();
    code.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> execute() async {
    if (!form.currentState!.validate() ||
        (registration && newPassword.text != confirmPassword.text) || busy ||
        widget.challengeProvider == null || widget.onSession == null) {
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      if (registration && challenge != null) {
        final session = await widget.api.verifyOtp(
          challenge: challenge!, code: code.text.trim(),
          newPassword: newPassword.text,
        );
        await widget.onSession!(session);
      } else {
        final proof = await widget.challengeProvider!();
        if (proof == null || proof.isEmpty) {
          if (mounted) {
            setState(() => error = 'Security challenge was not completed.');
          }
          return;
        }
        if (registration) {
          final newChallenge = await widget.api.startOtp(
            studentId: studentId.text.trim().toUpperCase(),
            email: email.text.trim(), turnstileToken: proof,
          );
          if (mounted) {
            setState(() => challenge = newChallenge);
          }
        } else {
          final session = await widget.api.passwordLogin(
            studentId: studentId.text.trim().toUpperCase(),
            password: password.text, turnstileToken: proof,
          );
          await widget.onSession!(session);
        }
      }
    } on HttpException catch (e) {
      // The API returns safe, predefined public errors; do not log user input.
      final serverMessage = e.message;
      const allowedErrors = <String>{
        'Invalid credentials or verification.',
        'Security verification required.',
        'Maximum device limit reached.',
        'Account access unavailable.',
        'Sign-in temporarily unavailable.',
        'Sign-in unavailable.',
        'Mobile sign-in is not enabled.',
        'Verification status unavailable.',
        'Invalid request.',
      };
      if (mounted) {
        setState(() {
          error = allowedErrors.contains(serverMessage)
              ? serverMessage
              : 'Unable to sign in. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Unable to sign in. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void refresh() => setState(() => availability = widget.api.isEnabled());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Student sign-in')),
    body: FutureBuilder<bool>(
      future: availability,
      builder: (context, snapshot) {
        final active = snapshot.data == true &&
            widget.challengeProvider != null && widget.onSession != null;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!active) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.verified_user_outlined, size: 43),
                      const SizedBox(height: 14),
                      const Text('Mobile sign-in not available yet',
                        key: Key('login-disabled'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800,
                          fontSize: 20)),
                      const SizedBox(height: 12),
                      const Text(
                        'Your account remains accessible on the website. '
                        'Mobile sign-in will open after secure verification '
                        'and session storage are enabled.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Check availability'),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          );
        }
        return Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
                      const Icon(Icons.auto_stories_rounded, size: 35),
              const SizedBox(height: 12),
              Text(registration ? 'Create your student account' : 'Welcome back',
                style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(registration
                ? 'Use your SMIU Student ID and email OTP. '
                  'Student Card verification is a separate step.'
                : 'Sign in with your existing SMIUNotes account.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: ChoiceChip(
                  key: const Key('login-mode-signin'),
                  label: const Center(child: Text('Sign in')),
                  selected: !registration,
                  onSelected: busy ? null : (_) => setState(() {
                    registration = false; challenge = null; error = null;
                    code.clear();
                  }),
                )),
                const SizedBox(width: 10),
                Expanded(child: ChoiceChip(
                  key: const Key('login-mode-register'),
                  label: const Center(child: Text('Register')),
                  selected: registration,
                  onSelected: busy ? null : (_) => setState(() {
                    registration = true; challenge = null; error = null;
                    code.clear();
                  }),
                )),
              ]),
              const SizedBox(height: 15),
              TextFormField(
                key: const Key('student-id'),
                controller: studentId,
                maxLength: 32,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Student ID'),
                validator: (value) => RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$')
                      .hasMatch((value ?? '').trim())
                    ? null : 'Enter a valid Student ID',
              ),
              if (registration && challenge == null) ...[
                TextFormField(
                  key: const Key('email'),
                  controller: email,
                  maxLength: 254,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address'),
                  validator: (value) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch((value ?? '').trim())
                      ? null : 'Enter a valid email address',
                ),
                TextFormField(
                  key: const Key('new-password'),
                  controller: newPassword,
                  obscureText: !revealPassword,
                  decoration: const InputDecoration(labelText: 'Create password'),
                  validator: (v) => (v?.length ?? 0) >= 12 &&
                          (v?.length ?? 0) <= 128
                      ? null : 'Use 12–128 characters',
                ),
                TextFormField(
                  key: const Key('confirm-password'),
                  controller: confirmPassword,
                  obscureText: !revealPassword,
                  decoration: const InputDecoration(labelText: 'Confirm password'),
                  validator: (v) => v == newPassword.text
                      ? null : 'Passwords do not match',
                ),
              ] else if (registration) ...[
                TextFormField(
                  key: const Key('otp-code'),
                  controller: code,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '6-digit code'),
                  validator: (value) => RegExp(r'^\d{6}$')
                        .hasMatch((value ?? '').trim())
                      ? null : 'Enter the 6-digit code',
                ),
                Text('Confirming the code will complete registration with '
                  'your chosen password.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ] else
                TextFormField(
                  key: const Key('password'),
                  controller: password,
                  obscureText: !revealPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() =>
                        revealPassword = !revealPassword),
                      icon: Icon(revealPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    ),
                  ),
                  validator: (value) => (value ?? '').isNotEmpty
                      ? null : 'Enter your password',
                ),
              const SizedBox(height: 14),
              if (error != null) Text(error!,
                style: const TextStyle(color: Colors.red)),
              FilledButton(
                key: const Key('login-submit'),
                onPressed: busy ? null : execute,
                child: Text(busy ? 'Processing…'
                  : registration
                    ? challenge == null ? 'Send verification code' : 'Verify & create account'
                    : 'Sign in'),
              ),
              if (!registration)
                TextButton(
                  key: const Key('open-account-recovery'),
                  onPressed: busy ? null : () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => StudentRecoveryPage(
                        api: widget.api,
                        challengeProvider: widget.challengeProvider!,
                      ),
                    ));
                  },
                  child: const Text('Forgot password? Recover account'),
                ),
              TextButton(
                onPressed: busy ? null : () => setState(() {
                  registration = !registration;
                  challenge = null;
                  error = null;
                  code.clear();
                  newPassword.clear();
                  confirmPassword.clear();
                }),
                child: Text(registration
                  ? 'Already registered? Sign in'
                  : 'First time here? Register your email'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
)
                      .hasMatch((value ?? '').trim())
                      ? null : 'Enter a valid email address',
                ),
                TextFormField(
                  key: const Key('new-password'),
                  controller: newPassword,
                  obscureText: !revealPassword,
                  decoration: const InputDecoration(labelText: 'Create password'),
                  validator: (v) => (v?.length ?? 0) >= 12 &&
                          (v?.length ?? 0) <= 128
                      ? null : 'Use 12–128 characters',
                ),
                TextFormField(
                  key: const Key('confirm-password'),
                  controller: confirmPassword,
                  obscureText: !revealPassword,
                  decoration: const InputDecoration(labelText: 'Confirm password'),
                  validator: (v) => v == newPassword.text
                      ? null : 'Passwords do not match',
                ),
              ] else if (registration) ...[
                TextFormField(
                  key: const Key('otp-code'),
                  controller: code,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '6-digit code'),
                  validator: (value) => RegExp(r'^\d{6}$')
                        .hasMatch((value ?? '').trim())
                      ? null : 'Enter the 6-digit code',
                ),
                TextFormField(
                  key: const Key('new-password'),
                  controller: newPassword,
                  obscureText: !revealPassword,
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (value) => (value?.length ?? 0) >= 12 &&
                          (value?.length ?? 0) <= 128
                      ? null : 'Use 12–128 characters',
                ),
              ] else
                TextFormField(
                  key: const Key('password'),
                  controller: password,
                  obscureText: !revealPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() =>
                        revealPassword = !revealPassword),
                      icon: Icon(revealPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    ),
                  ),
                  validator: (value) => (value ?? '').isNotEmpty
                      ? null : 'Enter your password',
                ),
              const SizedBox(height: 14),
              if (error != null) Text(error!,
                style: const TextStyle(color: Colors.red)),
              FilledButton(
                key: const Key('login-submit'),
                onPressed: busy ? null : execute,
                child: Text(busy ? 'Processing…'
                  : registration
                    ? challenge == null ? 'Send code' : 'Verify code'
                    : 'Sign in'),
              ),
              if (!registration)
                TextButton(
                  key: const Key('open-account-recovery'),
                  onPressed: busy ? null : () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => StudentRecoveryPage(
                        api: widget.api,
                        challengeProvider: widget.challengeProvider!,
                      ),
                    ));
                  },
                  child: const Text('Forgot password? Recover account'),
                ),
              TextButton(
                onPressed: busy ? null : () => setState(() {
                  registration = !registration;
                  challenge = null;
                  error = null;
                  code.clear();
                  newPassword.clear();
                }),
                child: Text(registration
                  ? 'Already registered? Sign in'
                  : 'First time here? Register your email'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
