import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smiunotes_mobile/models/member_notification.dart';
import 'package:smiunotes_mobile/screens/notification_inbox_page.dart';

MemberNotification notification({bool read = false}) => MemberNotification(
  id: 'd1ee4444-5555-4666-8777-888888888888',
  category: 'verification',
  title: 'Verification decision',
  message: 'Your verification status changed.',
  createdAt: DateTime.utc(2026, 11, 21),
  isRead: read,
);

void main() {
  testWidgets('guest inbox never invokes a loader', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NotificationInboxPage(),
    ));
    expect(find.byKey(const Key('notifications-auth-required')), findsOneWidget);
    expect(find.byKey(const Key('notifications-read')), findsNothing);
  });

  testWidgets('empty inbox can refresh and load a new notification', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: NotificationInboxPage(
        loader: () async {
          calls++;
          return MemberNotificationInbox(
            unread: calls == 1 ? 0 : 1,
            items: calls == 1 ? [] : [notification()],
          );
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('notifications-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('1 unread'), findsOneWidget);
    expect(find.text('Verification decision'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('mark-read refreshes own inbox after successful mutation', (tester) async {
    var read = false;
    var markCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: NotificationInboxPage(
        loader: () async => MemberNotificationInbox(
          unread: read ? 0 : 1,
          items: [notification(read: read)],
        ),
        markRead: (id) async {
          expect(id, notification().id);
          markCalls++;
          read = true;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('notification-read-${notification().id}')));
    await tester.pumpAndSettle();
    expect(markCalls, 1);
    expect(find.text('0 unread'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('failed mutation reports recoverable error and retains inbox', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NotificationInboxPage(
        loader: () async => MemberNotificationInbox(
          unread: 1, items: [notification()],
        ),
        markRead: (_) async => throw StateError('Backend failure'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('notification-read-${notification().id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notification-action-error')), findsOneWidget);
    expect(find.text('Verification decision'), findsOneWidget);
    expect(find.text('1 unread'), findsOneWidget);
  });

  testWidgets('clear own notifications reloads empty inbox', (tester) async {
    var cleared = false;
    var clearCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: NotificationInboxPage(
        loader: () async => MemberNotificationInbox(
          unread: cleared ? 0 : 1,
          items: cleared ? [] : [notification()],
        ),
        clearOwn: () async {
          clearCalls++;
          cleared = true;
          return 1;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notifications-clear')));
    await tester.pumpAndSettle();
    expect(clearCalls, 1);
    expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
    expect(find.byKey(const Key('notifications-refresh')), findsOneWidget);
  });
}
