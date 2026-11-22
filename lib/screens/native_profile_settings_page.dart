import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import '../models/student_profile.dart';
import '../services/mobile_auth_api.dart';
import 'student_login_page.dart';
import 'student_recovery_page.dart';
import 'student_verification_status_page.dart';
import '../widgets/profile_avatar.dart';

/// Native, read-only account settings backed by the validated /me profile.
/// Mutations are deliberately not offered until equivalent secured mobile
/// endpoints exist; account recovery already has a Turnstile-protected API.
class NativeProfileSettingsPage extends StatefulWidget {
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
    this.onLoadAvatar,
  });

  final StudentProfile profile;
  final MobileAuthApi api;
  final ChallengeProvider challengeProvider;
  final bool darkMode;
  final ValueChanged<bool>? onThemeChanged;
  final bool pushAvailable, pushEnabled, pushBusy;
  final ValueChanged<bool>? onPushChanged;
  final Future<void> Function()? onSignOutAll;
  final Future<Uint8List?> Function()? onLoadAvatar;

  @override
  State<NativeProfileSettingsPage> createState() => _NativeProfileSettingsPageState();
}

class _NativeProfileSettingsPageState extends State<NativeProfileSettingsPage> {
  late bool _darkMode;
  late bool _pushEnabled;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.darkMode;
    _pushEnabled = widget.pushEnabled;
  }

  @override
  void didUpdateWidget(covariant NativeProfileSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.darkMode != oldWidget.darkMode) _darkMode = widget.darkMode;
    if (widget.pushEnabled != oldWidget.pushEnabled) _pushEnabled = widget.pushEnabled;
  }

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
                  name: widget.profile.studentName,
                  size: 70,
                  cacheKey: '${widget.profile.studentId}:${widget.profile.avatarVersion}',
                  imageLoader: widget.profile.avatarVersion == null
                    ? null : widget.onLoadAvatar,
                ),
                const SizedBox(height: 12),
                Text(widget.profile.studentName,
                  style: Theme.of(context).textTheme.titleLarge),
                if (widget.profile.studentId != null) Text(widget.profile.studentId!),
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
            subtitle: Text(widget.profile.verifiedEmail ?? 'Not provided'),
          ),
          ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: const Text('Department'),
            subtitle: Text(widget.profile.department ?? 'Not provided'),
          ),
          ListTile(
            key: const Key('settings-verification-status'),
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Student verification'),
            subtitle: Text(widget.profile.verificationStatus),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => StudentVerificationStatusPage(
                profile: widget.profile,
              ),
            )),
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Account status'),
            subtitle: Text(widget.profile.accountStatus),
          ),
          const Divider(height: 30),
          Text('Appearance & notifications',
            style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            key: const Key('settings-theme'),
            title: const Text('Dark mode'),
            secondary: const Icon(Icons.contrast),
            value: _darkMode,
            onChanged: widget.onThemeChanged == null ? null : (enabled) {
              setState(() => _darkMode = enabled);
              widget.onThemeChanged!(enabled);
            },
          ),
          if (widget.pushAvailable)
            SwitchListTile(
              key: const Key('settings-push'),
              title: const Text('Phone notifications'),
              subtitle: const Text('Account and university updates'),
              value: _pushEnabled,
              onChanged: widget.pushBusy || widget.onPushChanged == null
                ? null : (enabled) {
                  widget.onPushChanged!(enabled);
                  // Parent refresh confirms remote enrollment; no optimistic success.
                },
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
                api: widget.api,
                challengeProvider: widget.challengeProvider,
              ),
            )),
          ),
          if (widget.onSignOutAll != null)
            ListTile(
              key: const Key('settings-all-devices'),
              leading: const Icon(Icons.phonelink_erase_outlined),
              title: const Text('Sign out all devices'),
              subtitle: const Text('Revoke active sessions'),
              onTap: () async {
                await widget.onSignOutAll!();
                if (context.mounted) Navigator.of(context).pop();
              },
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
