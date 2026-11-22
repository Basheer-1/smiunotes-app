import 'package:material_ui/material_ui.dart';
import '../models/student_profile.dart';
import '../services/mobile_auth_api.dart';
import 'student_login_page.dart';
import 'student_recovery_page.dart';
import '../widgets/profile_avatar.dart';

/// Native, read-only account settings backed by the validated /me profile.
/// Mutations are deliberately not offered until equivalent secured mobile
/// endpoints exist; account recovery already has a Turnstile-protected API.
class NativeProfileSettingsPage extends StatelessWidget {
  const NativeProfileSettingsPage({
    super.key,
    required this.profile,
    required this.api,
    required this.challengeProvider,
    required this.darkMode,
    required this.onThemeChanged,
    this.pushAvailable = false,
    this.pushEnabled = false,
    this.pushBusy = false,
    this.onPushChanged,
    this.onSignOutAll,
  });

  final StudentProfile profile;
  final MobileAuthApi api;
  final ChallengeProvider challengeProvider;
  final bool darkMode;
  final ValueChanged<bool>? onThemeChanged;
  final bool pushAvailable, pushEnabled, pushBusy;
  final ValueChanged<bool>? onPushChanged;
  final Future<void> Function()? onSignOutAll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile settings')),
      body: ListView(
        key: const Key('native-profile-settings'),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 35),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                ProfileAvatar(
                  name: profile.studentName,
                  size: 70,
                  cacheKey: '${profile.studentId}:${profile.avatarVersion}',
                ),
                const SizedBox(height: 12),
                Text(profile.studentName,
                  style: Theme.of(context).textTheme.titleLarge),
                if (profile.studentId != null) Text(profile.studentId!),
                const SizedBox(height: 10),
                Text('Profile data is synced from your verified SMIUNotes account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text('Account details',
            style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: const Text('Verified email'),
            subtitle: Text(profile.verifiedEmail ?? 'Not provided'),
          ),
          ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: const Text('Department'),
            subtitle: Text(profile.department ?? 'Not provided'),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Student verification'),
            subtitle: Text(profile.verificationStatus),
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Account status'),
            subtitle: Text(profile.accountStatus),
          ),
          const Divider(height: 30),
          Text('Appearance & notifications',
            style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            key: const Key('settings-theme'),
            title: const Text('Dark mode'),
            secondary: const Icon(Icons.contrast),
            value: darkMode,
            onChanged: onThemeChanged,
          ),
          if (pushAvailable)
            SwitchListTile(
              key: const Key('settings-push'),
              title: const Text('Phone notifications'),
              subtitle: const Text('Account and university updates'),
              value: pushEnabled,
              onChanged: pushBusy ? null : onPushChanged,
            ),
          const Divider(height: 30),
          Text('Security & recovery',
            style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            key: const Key('settings-account-recovery'),
            leading: const Icon(Icons.help_outline),
            title: const Text('Account recovery'),
            subtitle: const Text('Secure request with verification'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => StudentRecoveryPage(
                api: api,
                challengeProvider: challengeProvider,
              ),
            )),
          ),
          if (onSignOutAll != null)
            ListTile(
              key: const Key('settings-all-devices'),
              leading: const Icon(Icons.phonelink_erase_outlined),
              title: const Text('Sign out all devices'),
              subtitle: const Text('Revoke active sessions'),
              onTap: () => onSignOutAll!(),
            ),
          const SizedBox(height: 14),
          Text(
            'Changes to student identity, email and verification documents '
            'remain protected by the website until secure mobile endpoints '
            'are available.',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
