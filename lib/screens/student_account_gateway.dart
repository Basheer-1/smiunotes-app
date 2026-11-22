import 'package:material_ui/material_ui.dart';
import 'dart:typed_data';

import '../models/student_profile.dart';
import '../services/mobile_auth_api.dart';
import 'student_login_page.dart';
import '../widgets/profile_avatar.dart';
import 'native_information_pages.dart';
import 'native_profile_settings_page.dart';

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
    this.onCreateDiscussion,
    this.onOpenVerifiedNote,
    this.onOpenNotifications,
    this.onOpenBookmarks,
    this.onEnablePush,
    this.onDisablePush,
    this.onLoadPushEnabled,
    this.pushAvailable = false,
    this.onProfileChanged,
    this.onThemeChanged,
    this.darkMode = false,
    this.signOutAll,
    this.onLoadAvatar,
  });

  final MobileAuthApi api;
  final ChallengeProvider challengeProvider;
  final Future<void> Function(MobileSession) acceptAndVerify;
  final Future<bool> Function() restoreAndVerify;
  final StudentProfile? Function() loadValidatedProfile;
  final Future<void> Function() signOut;
  final VoidCallback? onCreateDiscussion;
  final VoidCallback? onOpenVerifiedNote;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenBookmarks;
  final Future<void> Function()? onEnablePush;
  final Future<void> Function()? onDisablePush;
  final Future<bool> Function()? onLoadPushEnabled;
  final bool pushAvailable;
  final ValueChanged<StudentProfile?>? onProfileChanged;
  final ValueChanged<bool>? onThemeChanged;
  final bool darkMode;
  final Future<void> Function()? signOutAll;
  final Future<Uint8List?> Function()? onLoadAvatar;

  @override
  State<StudentAccountGateway> createState() => _StudentAccountGatewayState();
}

class _StudentAccountGatewayState extends State<StudentAccountGateway> {
  late Future<bool> _restoring;
  StudentProfile? _profile;
  bool _busy = false;
  bool _pushEnabled = false;
  bool _pushBusy = false;
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
      widget.onProfileChanged?.call(_profile);
      if (restored && _profile != null && widget.pushAvailable &&
          widget.onLoadPushEnabled != null) {
        final enabled = await widget.onLoadPushEnabled!();
        if (mounted) setState(() => _pushEnabled = enabled);
      } else if (mounted) {
        setState(() => _pushEnabled = false);
      }
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
    final enabled = widget.pushAvailable && widget.onLoadPushEnabled != null
        ? await widget.onLoadPushEnabled!()
        : false;
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _pushEnabled = enabled;
      _error = null;
    });
    widget.onProfileChanged?.call(profile);
    Navigator.of(context).pop();
  }

  Future<void> _togglePush(bool enabled) async {
    if (_pushBusy || _busy || !widget.pushAvailable || _profile == null) return;
    setState(() { _pushBusy = true; _error = null; });
    try {
      if (enabled) {
        final action = widget.onEnablePush;
        if (action == null) throw StateError('Push enrollment unavailable.');
        await action();
      } else {
        final action = widget.onDisablePush;
        if (action == null) throw StateError('Push removal unavailable.');
        await action();
      }
      if (mounted) setState(() => _pushEnabled = enabled);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to change push notifications. Try again.');
      }
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  Future<void> _logout() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _profile = null;
    });
    widget.onProfileChanged?.call(null);
    try {
      if (widget.pushAvailable && widget.onDisablePush != null) {
        try {
          await widget.onDisablePush!();
        } catch (_) {
          // Local sign-out is required even if the remote device is offline.
        }
      }
      _pushEnabled = false;
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

  Future<bool> _confirmLogoutAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out all devices?'),
        content: const Text('This will revoke your other SMIUNotes sessions. '
          'You will need to sign in again on each device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out all')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _logoutAll();
      return true;
    }
    return false;
  }

  Future<void> _logoutAll() async {
    if (_busy || widget.signOutAll == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.signOutAll!();
      if (!mounted) return;
      setState(() { _profile = null; _pushEnabled = false; });
      widget.onProfileChanged?.call(null);
    } catch (_) {
      if (mounted) { setState(() {
        _profile = null;
        _pushEnabled = false;
        _error = 'All-device sign out could not be confirmed; this device was cleared.';
      }); }
      widget.onProfileChanged?.call(null);
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
      final colors = Theme.of(context).colorScheme;
      return SingleChildScrollView(
        key: const Key('account-gateway'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 122),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Your Profile', style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Your space for study, account and preferences.',
            style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 18),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, key: const Key('account-error'),
                style: TextStyle(color: colors.error))),
          if (_profile == null) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const ProfileAvatar(size: 70),
                  const SizedBox(height: 14),
                  const Text('Welcome to SMIUNotes',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  Text('Browse freely, or sign in to sync your study library and access your student profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant, height: 1.5)),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('account-open-login'),
                    onPressed: _busy ? null : _openLogin,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Log in / Register'),
                  ),
                ]),
              ),
            ),
          ] else ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: colors.outlineVariant)),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      ProfileAvatar(name: _profile!.studentName, size: 58,
                        cacheKey: '${_profile!.studentId}:${_profile!.avatarVersion}',
                        imageLoader: _profile!.avatarVersion == null ? null : widget.onLoadAvatar),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your account',
                            style: const TextStyle(fontSize: 21,
                              fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('SMIUNotes student account',
                            style: TextStyle(color: colors.onSurfaceVariant)),
                        ],
                      )),
                    ]),
                    const Divider(height: 34),
                    _ProfileDetail('Name', _profile!.studentName),
                    if (_profile!.studentId != null)
                      _ProfileDetail('Student ID', _profile!.studentId!),
                    if (_profile!.verifiedEmail != null)
                      _ProfileDetail('Verified email', _profile!.verifiedEmail!),
                    _ProfileDetail('Roles', _profile!.role),
                    _ProfileDetail('Account status', _profile!.accountStatus),
                    if (_profile!.department != null)
                      _ProfileDetail('Department', _profile!.department!),
                    _ProfileDetail('Verification', _profile!.verificationStatus),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _AccountEntry(
              icon: Icons.manage_accounts_outlined,
              label: 'Profile settings',
              entryKey: const Key('account-profile-settings'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => NativeProfileSettingsPage(
                  profile: _profile!,
                  api: widget.api,
                  challengeProvider: widget.challengeProvider,
                  darkMode: widget.darkMode,
                  onThemeChanged: widget.onThemeChanged,
                  pushAvailable: widget.pushAvailable,
                  pushEnabled: _pushEnabled,
                  pushBusy: _pushBusy,
                  onPushChanged: _togglePush,
                  onSignOutAll: _confirmLogoutAll,
                  onLoadAvatar: widget.onLoadAvatar,
                ),
              )),
            ),
            _AccountEntry(
              icon: Icons.bookmarks_outlined, label: 'My study library',
              onTap: widget.onOpenBookmarks,
              entryKey: const Key('account-open-bookmarks'),
            ),
            _AccountEntry(
              icon: Icons.notifications_outlined,
              label: 'My notifications',
              onTap: widget.onOpenNotifications,
              entryKey: const Key('account-open-notifications'),
            ),
            if (_profile!.verificationStatus == 'verified' &&
                widget.onCreateDiscussion != null)
              _AccountEntry(
                icon: Icons.forum_outlined, label: 'New Community discussion',
                onTap: widget.onCreateDiscussion,
                entryKey: const Key('account-create-discussion'),
              ),
            if (_profile!.verificationStatus == 'verified' &&
                widget.onOpenVerifiedNote != null)
              _AccountEntry(
                icon: Icons.menu_book_outlined,
                label: 'Open a verified note (QA)',
                onTap: widget.onOpenVerifiedNote,
                entryKey: const Key('account-open-verified-note'),
              ),
          ],
          const SizedBox(height: 20),
          Text('Preferences', style: TextStyle(
            color: colors.onSurface, fontWeight: FontWeight.w800, fontSize: 19)),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: Column(children: [
              SwitchListTile(
                key: const Key('account-theme-switch'),
                title: const Text('Light / dark theme'),
                secondary: Icon(widget.darkMode
                    ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
                value: widget.darkMode,
                onChanged: widget.onThemeChanged,
              ),
              if (_profile != null && widget.pushAvailable)
                SwitchListTile(
                  key: const Key('account-push-optin'),
                  title: const Text('Phone notifications'),
                  subtitle: const Text('Account and university updates. No new-notes spam.'),
                  value: _pushEnabled,
                  onChanged: (_busy || _pushBusy)
                    ? null : (enabled) => _togglePush(enabled),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Text('Explore & help', style: TextStyle(
            color: colors.onSurface, fontWeight: FontWeight.w800, fontSize: 19)),
          const SizedBox(height: 10),
          _AccountEntry(icon: Icons.favorite_outline, label: 'Support SMIUNotes',
            entryKey: const Key('account-support'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const NativeInformationPage(kind: 'support')))),
          _AccountEntry(icon: Icons.mail_outline, label: 'Contact Us',
            entryKey: const Key('account-contact'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const NativeInformationPage(kind: 'contact')))),
          if (_profile != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              key: const Key('account-signout'),
              onPressed: _busy ? null : _logout,
              icon: const Icon(Icons.logout_rounded),
              label: Text(_busy ? 'Signing out…' : 'Logout'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('account-signout-all'),
              onPressed: _busy || widget.signOutAll == null ? null : () {
                _confirmLogoutAll();
              },
              icon: const Icon(Icons.phonelink_erase_rounded),
              label: const Text('Sign out all devices'),
            ),
            const SizedBox(height: 8),
            Text('This app provides the same student-facing experience for every role.',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
          ],
        ]),
      );
    },
  );
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 3),
      SelectableText(value, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _AccountEntry extends StatelessWidget {
  const _AccountEntry({required this.icon, required this.label, this.onTap,
    this.entryKey});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Key? entryKey;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 9),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ListTile(
      key: entryKey,
      minTileHeight: 55,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}
