import 'package:material_ui/material_ui.dart';
import '../models/member_notification.dart';

/// No account data is fetched without an authenticated injected loader.
class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key, this.loader});
  final Future<MemberNotificationInbox> Function()? loader;
  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  Future<MemberNotificationInbox>? _future;
  @override
  void initState() { super.initState(); _reload(); }
  @override
  void didUpdateWidget(covariant NotificationInboxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader) _reload();
  }

  void _reload() {
    final loader = widget.loader;
    _future = loader == null ? null : Future<MemberNotificationInbox>.sync(loader);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: ListView(
      key: const Key('notifications-inbox'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text('Your SMIUNotes inbox',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('University updates, verification decisions and important '
          'account activity. New-note broadcasts are disabled.'),
        const SizedBox(height: 24),
        if (_future == null)
          const Card(child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Mobile account notifications are not enabled in this preview. '
              'A verified student sign-in is required.',
              key: Key('notifications-auth-required'),
            ),
          ))
        else
          FutureBuilder<MemberNotificationInbox>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Column(children: [
                  const Text('Unable to load notifications. Please retry.'),
                  OutlinedButton.icon(
                    key: const Key('notifications-retry'),
                    onPressed: () => setState(_reload),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ]);
              }
              final inbox = snapshot.data!;
              if (inbox.items.isEmpty) {
                return const Text('No notifications yet.',
                  key: Key('notifications-empty'));
              }
              final unread = inbox.unread;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$unread unread'),
                  const SizedBox(height: 8),
                  for (final item in inbox.items)
                    Card(child: ListTile(
                      title: Text(item.title),
                      subtitle: Text(item.message),
                      trailing: Text(item.isRead ? 'Read' : 'New'),
                    )),
                  OutlinedButton.icon(
                    key: const Key('notifications-refresh'),
                    onPressed: () => setState(_reload),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              );
            },
          ),
      ],
    ),
  );
}
