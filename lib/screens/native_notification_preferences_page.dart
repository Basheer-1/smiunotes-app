import 'package:material_ui/material_ui.dart';
import '../services/mobile_preferences_api.dart';

/// Native university updates preference, persisted through the same backend
/// as the website. No control for mandatory alerts or new-note spam.
class NativeNotificationPreferencesPage extends StatefulWidget {
  const NativeNotificationPreferencesPage({
    super.key,
    required this.api,
    required this.currentAccessToken,
  });
  final MobilePreferencesApi api;
  final String Function() currentAccessToken;

  @override
  State<NativeNotificationPreferencesPage> createState() =>
      _NativeNotificationPreferencesPageState();
}

class _NativeNotificationPreferencesPageState
    extends State<NativeNotificationPreferencesPage> {
  late Future<bool> _initial;
  bool? _enabled;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _initial = widget.api.load(widget.currentAccessToken());
  }

  Future<void> _change(bool enabled) async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      final confirmed = await widget.api.save(
        widget.currentAccessToken(), enabled);
      if (!mounted) return;
      setState(() => _enabled = confirmed);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to save preference. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notification preferences')),
    body: FutureBuilder<bool>(
      future: _initial,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load notification preferences.'),
              OutlinedButton.icon(
                onPressed: () => setState(_refresh),
                icon: const Icon(Icons.refresh), label: const Text('Retry'),
              ),
            ],
          ));
        }
        final enabled = _enabled ?? snapshot.data!;
        return ListView(
          key: const Key('native-notification-preferences'),
          padding: const EdgeInsets.all(18),
          children: [
            Card(child: SwitchListTile(
              key: const Key('notify-university-updates'),
              title: const Text('University updates and opportunities'),
              subtitle: const Text('Choose whether to receive news updates.'),
              value: enabled,
              onChanged: _saving ? null : _change,
            )),
            const SizedBox(height: 14),
            const ListTile(
              leading: Icon(Icons.security_outlined),
              title: Text('Essential account alerts'),
              subtitle: Text('Always enabled for account security and verification.'),
              trailing: Icon(Icons.lock_outline),
            ),
            const ListTile(
              leading: Icon(Icons.notifications_off_outlined),
              title: Text('Every new note published'),
              subtitle: Text('Disabled to avoid unnecessary notifications.'),
              trailing: Icon(Icons.notifications_off_outlined),
            ),
            if (_saving) const LinearProgressIndicator(),
            if (_error != null) Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: TextStyle(
                color: Theme.of(context).colorScheme.error)),
            ),
          ],
        );
      },
    ),
  );
}
