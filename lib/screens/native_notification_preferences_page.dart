import 'package:material_ui/material_ui.dart';

/// One-account updates subscription preference, independent from Android
/// system permission and FCM device enrolment.
class NativeNotificationPreferencesPage extends StatefulWidget {
  const NativeNotificationPreferencesPage({
    super.key, required this.load, required this.save,
  });
  final Future<bool> Function() load;
  final Future<void> Function(bool) save;

  @override
  State<NativeNotificationPreferencesPage> createState() =>
      _NativeNotificationPreferencesPageState();
}

class _NativeNotificationPreferencesPageState
    extends State<NativeNotificationPreferencesPage> {
  bool? enabled;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() { enabled = null; error = null; });
    try {
      final value = await widget.load();
      if (mounted) setState(() => enabled = value);
    } catch (_) {
      if (mounted) setState(() {
        error = 'Unable to load your preferences. Check your sign-in.';
      });
    }
  }

  Future<void> _setEnabled(bool value) async {
    if (saving || enabled == null) return;
    setState(() { saving = true; error = null; });
    try {
      await widget.save(value);
      if (mounted) setState(() => enabled = value);
    } catch (_) {
      if (mounted) setState(() {
        error = 'Could not save. Your previous preference is unchanged.';
      });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification preferences')),
      body: SafeArea(child: ListView(
        key: const Key('native-notification-preferences'),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                colors.primary, const Color(0xFF4775AB),
              ]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.notifications_active_outlined,
                  color: Colors.white, size: 32),
                SizedBox(height: 13),
                Text('Your alerts, your choice.',
                  style: TextStyle(color: Colors.white,
                    fontSize: 24, fontWeight: FontWeight.w900)),
                SizedBox(height: 10),
                Text('Choose which optional university updates you receive. Essential account and security alerts stay enabled.',
                  style: TextStyle(color: Colors.white, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (enabled == null && error == null)
            const Center(child: Padding(padding: EdgeInsets.all(20),
              child: CircularProgressIndicator())),
          if (error != null) ...[
            Text(error!, key: const Key('preference-error'),
              style: TextStyle(color: colors.error)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('preference-retry'),
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
          if (enabled != null) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19),
                side: BorderSide(color: colors.outlineVariant)),
              child: SwitchListTile(
                key: const Key('notify-updates-toggle'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                title: const Text('University updates and opportunities',
                  style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Optional announcements, deadlines, events and opportunities.'),
                secondary: const Icon(Icons.campaign_outlined),
                value: enabled!,
                onChanged: saving ? null : _setEnabled,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: const ListTile(
                leading: Icon(Icons.shield_outlined),
                title: Text('Essential account alerts'),
                subtitle: Text('Verification, security and important account decisions remain enabled.'),
                trailing: Icon(Icons.lock_outline),
              ),
            ),
            Card(
              elevation: 0,
              child: const ListTile(
                leading: Icon(Icons.notifications_off_outlined),
                title: Text('Newly published notes'),
                subtitle: Text('Broadcast notifications for every new note are disabled.'),
                trailing: Icon(Icons.check_circle_outline),
              ),
            ),
            const SizedBox(height: 14),
            Text('Phone push delivery is controlled separately in your profile and Android notification settings. This preference also applies to your website account.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.5,
                fontSize: 13)),
          ],
        ],
      )),
    );
  }
}
