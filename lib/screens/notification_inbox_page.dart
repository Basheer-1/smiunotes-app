import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../models/member_notification.dart';

/// No account data is fetched without an authenticated injected loader.
class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({
    super.key, this.loader, this.markRead, this.clearOwn,
  });
  final Future<MemberNotificationInbox> Function()? loader;
  final Future<void> Function(String id)? markRead;
  final Future<int> Function()? clearOwn;
  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  Future<MemberNotificationInbox>? _future;
  bool _mutating = false;
  String? _actionError;

  Future<void> _change(Future<void> Function() action) async {
    if (_mutating) return;
    setState(() { _mutating = true; _actionError = null; });
    try {
      await action();
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) {
        setState(() => _actionError =
            'Unable to update notifications. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }
  @override
  void initState() { super.initState(); _reload(); }
  @override
  void didUpdateWidget(covariant NotificationInboxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader) _reload();
  }

  void _reload() {
    final loader = widget.loader;
    if (loader == null) {
      _future = null;
      return;
    }
    // Install the FutureBuilder listener first. A revoked session can fail
    // immediately; launching in setState would race the widget subscription.
    final pending = Completer<MemberNotificationInbox>();
    _future = pending.future;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        pending.complete(await loader());
      } catch (error, stack) {
        pending.completeError(error, stack);
      }
    });
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
        if (_actionError != null)
          Text(_actionError!, key: const Key('notification-action-error')),
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
                return Column(
                  children: [
                    const Text('No notifications yet.',
                      key: Key('notifications-empty')),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('notifications-refresh'),
                      onPressed: () => setState(_reload),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                );
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
                      trailing: item.isRead || widget.markRead == null
                          ? Text(item.isRead ? 'Read' : 'New')
                          : TextButton(
                              key: Key('notification-read-${item.id}'),
                              onPressed: _mutating ? null : () => _change(
                                () => widget.markRead!(item.id)),
                              child: const Text('Mark read'),
                            ),
                    )),
                  if (widget.clearOwn != null)
                    TextButton.icon(
                      key: const Key('notifications-clear'),
                      onPressed: _mutating ? null : () => _change(() async {
                        await widget.clearOwn!();
                      }),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear my inbox'),
                    ),
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
