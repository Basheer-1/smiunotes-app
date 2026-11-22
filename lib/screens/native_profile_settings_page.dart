import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import '../models/student_profile.dart';
import '../services/mobile_auth_api.dart';
import '../services/native_profile_settings_api.dart';
import '../services/native_student_forms_api.dart';
import 'student_login_page.dart';
import 'student_recovery_page.dart';
import 'student_verification_status_page.dart';
import '../widgets/profile_avatar.dart';

/// Native mirror of the public website's /profile settings: profile photo,
/// verified identity, password, active devices, alerts and study library.
/// Server-side actions require the current RLS-verified bearer session.
class NativeProfileSettingsPage extends StatefulWidget {
  const NativeProfileSettingsPage({
    super.key,
    required this.profile,
    required this.api,
    required this.challengeProvider,
    required this.darkMode,
    required this.onThemeChanged,
    this.profileSettingsApi,
    this.onAvatarChanged,
    this.onOpenLibrary,
    this.onOpenNotificationPreferences,
    this.onOpenNotifications,
    this.pushAvailable = false,
    this.pushEnabled = false,
    this.pushBusy = false,
    this.onPushChanged,
    this.onSignOutAll,
    this.onLoadAvatar,
    this.onOpenNativeCardVerification,
  });
  final StudentProfile profile;
  final MobileAuthApi api;
  final ChallengeProvider challengeProvider;
  final bool darkMode;
  final ValueChanged<bool>? onThemeChanged;
  final NativeProfileSettingsApi? profileSettingsApi;
  final Future<StudentProfile?> Function()? onAvatarChanged;
  final VoidCallback? onOpenLibrary;
  final VoidCallback? onOpenNotificationPreferences;
  final VoidCallback? onOpenNotifications;
  final bool pushAvailable, pushEnabled, pushBusy;
  final ValueChanged<bool>? onPushChanged;
  final Future<bool> Function()? onSignOutAll;
  final Future<Uint8List?> Function()? onLoadAvatar;
  final VoidCallback? onOpenNativeCardVerification;

  @override
  State<NativeProfileSettingsPage> createState() =>
      _NativeProfileSettingsPageState();
}

class _NativeProfileSettingsPageState extends State<NativeProfileSettingsPage> {
  late bool _darkMode;
  late bool _pushEnabled;
  Future<Map<String, dynamic>>? _settings;
  bool _busy = false;
  String? _feedback;
  int _avatarRevision = 0;
  late StudentProfile _liveProfile;

  @override
  void initState() {
    super.initState();
    _liveProfile = widget.profile;
    _darkMode = widget.darkMode;
    _pushEnabled = widget.pushEnabled;
    _refresh();
  }

  void _refresh() {
    if (widget.profileSettingsApi != null) {
      _settings = widget.profileSettingsApi!.loadSettings();
    }
  }

  @override
  void didUpdateWidget(covariant NativeProfileSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profile != oldWidget.profile) _liveProfile = widget.profile;
    if (widget.darkMode != oldWidget.darkMode) _darkMode = widget.darkMode;
    if (widget.pushEnabled != oldWidget.pushEnabled) {
      _pushEnabled = widget.pushEnabled;
    }
    if (widget.profileSettingsApi != oldWidget.profileSettingsApi) _refresh();
  }

  Future<void> _changePhoto({bool remove = false}) async {
    final api = widget.profileSettingsApi;
    if (api == null || _busy) return;
    Uint8List? bytes;
    if (!remove) {
      try {
        bytes = await NativeStudentFormsApi.chooseImage();
        if (bytes == null) return;
      } catch (_) {
        if (mounted) { setState(() => _feedback =
          'Choose a JPG, PNG or WebP profile photo smaller than 2 MB.'); }
        return;
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Remove profile photo?'),
          content: const Text('Your initials will be used instead.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Remove')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) { return; }
    setState(() { _busy = true; _feedback = null; });
    try {
      if (remove) {
        await api.removePhoto();
      } else {
        await api.savePhoto(bytes!);
      }
      final refreshed = await widget.onAvatarChanged?.call();
      if (mounted) { setState(() {
        if (refreshed != null) _liveProfile = refreshed;
        _avatarRevision++;
        _feedback = remove ? 'Profile photo removed.' : 'Profile photo updated.';
      }); }
    } catch (_) {
      if (mounted) { setState(() => _feedback =
        'Profile photo change is unavailable. Your existing photo is unchanged.'); }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    final api = widget.profileSettingsApi;
    if (api == null) return;
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    bool submitting = false;
    bool reveal = false;
    final key = GlobalKey<FormState>();
    try {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(builder: (context, change) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              22, 12, 22, MediaQuery.viewInsetsOf(context).bottom + 22),
            child: Form(
              key: key,
              child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Change password',
                    style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  const Text('Your Student ID, library and verification '
                    'status will not change.'),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const Key('settings-current-password'),
                    controller: current, obscureText: !reveal,
                    decoration: const InputDecoration(
                      labelText: 'Current password'),
                    validator: (v) => (v ?? '').isEmpty
                      ? 'Enter your current password' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('settings-new-password'),
                    controller: next, obscureText: !reveal,
                    decoration: const InputDecoration(
                      labelText: 'New password'),
                    validator: (v) => (v?.length ?? 0) < 12 ||
                        (v?.length ?? 0) > 128
                      ? 'Use 12–128 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirm, obscureText: !reveal,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password'),
                    validator: (v) => v == next.text
                      ? null : 'Passwords do not match',
                  ),
                  SwitchListTile(
                    title: const Text('Show passwords'),
                    value: reveal,
                    onChanged: (value) => change(() => reveal = value),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    key: const Key('settings-change-password-confirm'),
                    onPressed: submitting ? null : () async {
                      if (key.currentState?.validate() != true ||
                          next.text == current.text) { return; }
                      change(() => submitting = true);
                      try {
                        await api.changePassword(
                          current.text, next.text, confirm.text);
                        if (!sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                        if (mounted) { setState(() => _feedback =
                          'Password updated. Use it for future sign-ins.'); }
                      } catch (_) {
                        if (mounted) { setState(() => _feedback =
                          'Could not update password. Check the current '
                          'password or try again later.'); }
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      } finally {
                        if (sheetContext.mounted) {
                          change(() => submitting = false);
                        }
                      }
                    },
                    child: Text(submitting ? 'Updating…' : 'Update password'),
                  ),
                ],
              )),
            ),
          );
        }),
      );
    } finally {
      current.dispose(); next.dispose(); confirm.dispose();
    }
  }

  Future<void> _deviceAction(Map<String, dynamic> device, bool remove) async {
    final api = widget.profileSettingsApi;
    if (api == null || _busy) return;
    final id = device['id']?.toString() ?? '';
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) return;
    String? nickname;
    if (remove) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Sign out device?'),
          content: const Text('The selected device will need to sign in again.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Sign out device')),
          ],
        ),
      );
      if (confirmed != true) return;
    } else {
      final input = TextEditingController(
        text: device['nickname']?.toString() ?? '');
      try {
        nickname = await showDialog<String>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Name this device'),
            content: TextField(
              controller: input, maxLength: 60,
              decoration: const InputDecoration(
                hintText: 'My phone, Office laptop'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancel')),
              FilledButton(onPressed: () =>
                Navigator.pop(dialog, input.text.trim()),
                child: const Text('Save name')),
            ],
          ),
        );
      } finally { input.dispose(); }
      if (nickname == null || nickname.length < 2 ||
          nickname.length > 60) { return; }
    }
    if (!mounted) return;
    setState(() { _busy = true; _feedback = null; });
    try {
      if (remove) {
        await api.removeDevice(id);
      } else {
        await api.renameDevice(id, nickname!);
      }
      if (mounted) { setState(() {
        _refresh();
        _feedback = remove ? 'Device signed out.' : 'Device renamed.';
      }); }
    } catch (_) {
      if (mounted) { setState(() => _feedback =
        'Device change unavailable. Please try again.'); }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(BuildContext context, String title, IconData icon,
      Widget content) {
    final c = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: c.surface.withValues(alpha: .90),
        border: Border.all(color: c.outlineVariant.withValues(alpha: .75)),
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: .05),
            blurRadius: 24, offset: const Offset(0, 9)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: c.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style:
                Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 12),
            content,
          ]),
        ),
      ),
    );
  }

  Widget _detail(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      SizedBox(width: 115, child: Text(title, style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant))),
      Expanded(child: SelectableText(value,
        style: const TextStyle(fontWeight: FontWeight.w700))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final profile = _liveProfile;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile settings')),
      body: ListView(
        key: const Key('native-profile-settings'),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 38),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [c.primaryContainer, c.surface],
              ),
              border: Border.all(color: c.outlineVariant),
            ),
            padding: const EdgeInsets.all(22),
            child: Column(children: [
              ProfileAvatar(name: profile.studentName, size: 80,
                cacheKey: '${profile.studentId}:${profile.avatarVersion}:$_avatarRevision',
                imageLoader: profile.avatarVersion == null
                    ? null : widget.onLoadAvatar),
              const SizedBox(height: 12),
              Text(profile.studentName, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900)),
              if (profile.studentId != null)
                Text(profile.studentId!, style: TextStyle(
                  color: c.onSurfaceVariant)),
              const SizedBox(height: 10),
              Chip(avatar: Icon(
                profile.verificationStatus == 'verified'
                  ? Icons.verified_rounded : Icons.pending_actions_outlined,
                color: c.primary, size: 18),
                label: Text(profile.verificationStatus == 'verified'
                  ? 'Verified student' : 'Verification: ${profile.verificationStatus}')),
            ]),
          ),
          if (_feedback != null) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_feedback!, key: const Key('settings-feedback'),
              style: TextStyle(color: c.primary)),
          ),
          _section(context, 'Your account', Icons.badge_outlined,
            Column(children: [
              _detail('Name', profile.studentName),
              _detail('Student ID', profile.studentId ?? 'Not provided'),
              _detail('Verified email', profile.verifiedEmail ?? 'Not provided'),
              _detail('Department', profile.department ?? 'Not specified'),
              _detail('Access', profile.role),
              ListTile(
                key: const Key('settings-verification-status'),
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('Student ID verification'),
                subtitle: Text(profile.verificationStatus),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) =>
                    StudentVerificationStatusPage(
                      profile: profile,
                      onOpenNativeCardVerification:
                        widget.onOpenNativeCardVerification,
                    ))),
              ),
            ]),
          ),
          _section(context, 'Profile picture', Icons.account_circle_outlined,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Optional · JPG, PNG, WebP · up to 2 MB',
                style: TextStyle(color: c.onSurfaceVariant)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 8, children: [
                FilledButton.icon(
                  key: const Key('settings-upload-photo'),
                  onPressed: _busy || widget.profileSettingsApi == null
                      ? null : _changePhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Change picture'),
                ),
                if (profile.avatarVersion != null)
                  OutlinedButton.icon(
                    onPressed: _busy || widget.profileSettingsApi == null
                        ? null : () => _changePhoto(remove: true),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ]),
            ]),
          ),
          _section(context, 'Password & account security', Icons.lock_outline,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Change your password without changing your student '
                'identity or saved notes.',
                style: TextStyle(color: c.onSurfaceVariant)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('settings-change-password'),
                onPressed: widget.profileSettingsApi == null
                    ? null : _changePassword,
                icon: const Icon(Icons.password_outlined),
                label: const Text('Change password'),
              ),
              ListTile(
                key: const Key('settings-account-recovery'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline),
                title: const Text('Account recovery'),
                subtitle: const Text('Email inaccessible or forgotten password'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => StudentRecoveryPage(
                    api: widget.api, challengeProvider: widget.challengeProvider))),
              ),
            ]),
          ),
          _section(context, 'Active devices', Icons.devices_outlined,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FutureBuilder<Map<String, dynamic>>(
                future: _settings,
                builder: (context, snapshot) {
                  if (_settings == null) {
                    return const Text('Device management is not configured.');
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator()));
                  }
                  if (!snapshot.hasData) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Device list is not available on this server.'),
                        TextButton(
                          onPressed: () => setState(_refresh),
                          child: const Text('Retry'),
                        ),
                      ],
                    );
                  }
                  final items = (snapshot.data!['devices'] as List<dynamic>? ?? [])
                      .whereType<Map<String, dynamic>>().toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${items.length} / 4 active sessions',
                        style: TextStyle(color: c.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      for (final item in items)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: c.surfaceContainerHighest.withValues(alpha: .45),
                          child: ListTile(
                            leading: const Icon(Icons.smartphone_outlined),
                            title: Text(item['nickname']?.toString()
                              .isNotEmpty == true
                              ? item['nickname'].toString()
                              : 'Signed-in device'),
                            subtitle: Text(item['current'] == true
                              ? 'This device · current session'
                              : 'Last seen: ${item['last_seen'] ?? 'Unknown'}'),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Device actions',
                              onSelected: (action) => _deviceAction(
                                item, action == 'remove'),
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'rename',
                                  child: Text('Rename')),
                                if (item['current'] != true)
                                  const PopupMenuItem(value: 'remove',
                                    child: Text('Sign out device')),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (widget.onSignOutAll != null)
                OutlinedButton.icon(
                  key: const Key('settings-all-devices'),
                  onPressed: _busy ? null : () async {
                    final signedOut = await widget.onSignOutAll!();
                    if (signedOut && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.phonelink_erase_outlined),
                  label: const Text('Sign out all devices'),
                ),
            ]),
          ),
          _section(context, 'Appearance & notifications',
            Icons.tune_rounded,
            Column(children: [
              SwitchListTile(
                key: const Key('settings-theme'),
                title: const Text('Dark mode'),
                subtitle: const Text('Archive Blue adaptive theme'),
                secondary: const Icon(Icons.contrast_outlined),
                value: _darkMode,
                onChanged: widget.onThemeChanged == null
                    ? null : (enabled) {
                      setState(() => _darkMode = enabled);
                      widget.onThemeChanged!(enabled);
                    },
              ),
              if (widget.onOpenNotificationPreferences != null)
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('University update alerts'),
                  subtitle: const Text('Essential alerts always on · no new-note spam'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onOpenNotificationPreferences,
                ),
              if (widget.pushAvailable)
                SwitchListTile(
                  key: const Key('settings-push'),
                  title: const Text('Phone notifications'),
                  value: _pushEnabled,
                  onChanged: widget.pushBusy || widget.onPushChanged == null
                      ? null : widget.onPushChanged,
                ),
              if (widget.onOpenNotifications != null)
                ListTile(
                  leading: const Icon(Icons.mark_email_read_outlined),
                  title: const Text('Notification inbox'),
                  onTap: widget.onOpenNotifications,
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
            ]),
          ),
          _section(context, 'My study library', Icons.bookmarks_outlined,
            ListTile(
              key: const Key('settings-my-library'),
              title: const Text('Bookmarks & completed notes'),
              subtitle: const Text('Continue where you left off'),
              trailing: const Icon(Icons.arrow_forward_rounded),
              onTap: widget.onOpenLibrary,
            ),
          ),
          const SizedBox(height: 16),
          Text('SMIUNotes is an independent student project. '
            'Your Student ID and verified email are managed by secure '
            'student verification, not editable in this app.',
            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
        ],
      ),
    );
  }
}
