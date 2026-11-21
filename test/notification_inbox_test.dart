import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/models/member_notification.dart';
import 'package:smiunotes_mobile/screens/notification_inbox_page.dart';

void main() {
  testWidgets('Guest inbox makes no authenticated notification request',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NotificationInboxPage()));
    expect(find.byKey(const Key('notifications-auth-required')), findsOneWidget);
  });
  testWidgets('Trusted loader displays own-account notifications',
      (tester) async {
    final inbox = MemberNotificationInbox.fromJson({
      'unread': 1,
      'items': [{
        'id': 'qa-notification', 'category': 'verification',
        'title': 'Student ID verified', 'message': 'Review complete.',
        'created_at': '2026-11-21T10:00:00Z', 'read_at': null,
      }],
    });
    await tester.pumpWidget(MaterialApp(
      home: NotificationInboxPage(loader: () async => inbox),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Student ID verified'), findsOneWidget);
    expect(find.text('1 unread'), findsOneWidget);
  });
  testWidgets('Failed inbox load permits retry', (tester) async {
    var tries = 0;
    Future<MemberNotificationInbox> load() async {
      tries++;
      if (tries == 1) throw StateError('offline');
      return const MemberNotificationInbox(items: [], unread: 0);
    }
    await tester.pumpWidget(MaterialApp(
      home: NotificationInboxPage(loader: load),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notifications-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
    expect(tries, 2);
  });
  testWidgets('Mark read and clear invoke only authenticated callbacks',
      (tester) async {
    var readCalls = 0;
    var clearCalls = 0;
    var inbox = MemberNotificationInbox.fromJson({
      'unread': 1,
      'items': [{
        'id': '00000000-0000-4000-8000-000000000001',
        'category': 'account',
        'title': 'Account verified',
        'message': 'Your account is verified.',
        'created_at': '2026-11-21T10:00:00Z',
        'read_at': null,
      }],
    });
    await tester.pumpWidget(MaterialApp(
      home: NotificationInboxPage(
        loader: () async => inbox,
        markRead: (id) async {
          expect(id, '00000000-0000-4000-8000-000000000001');
          readCalls++;
          inbox = const MemberNotificationInbox(items: [], unread: 0);
        },
        clearOwn: () async {
          clearCalls++;
          inbox = const MemberNotificationInbox(items: [], unread: 0);
          return 1;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      const Key('notification-read-00000000-0000-4000-8000-000000000001')));
    await tester.pumpAndSettle();
    expect(readCalls, 1);
    expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
    // Rebuild with an item to confirm the clear control invokes its callback.
    inbox = MemberNotificationInbox.fromJson({
      'unread': 1,
      'items': [{
        'id': '00000000-0000-4000-8000-000000000002',
        'category': 'account', 'title': 'Account update',
        'message': 'Please review.',
        'created_at': '2026-11-21T10:00:00Z', 'read_at': null,
      }],
    });
    await tester.pumpWidget(MaterialApp(
      home: NotificationInboxPage(
        loader: () async => inbox,
        clearOwn: () async {
          clearCalls++;
          inbox = const MemberNotificationInbox(items: [], unread: 0);
          return 1;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notifications-clear')));
    await tester.pumpAndSettle();
    expect(clearCalls, 1);
    expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
  });

  test('Invalid read timestamps fail closed', () {
    Map<String, dynamic> notification(Object? readAt) => {
      'id': 'n-1', 'category': 'verification',
      'title': 'Verified', 'message': 'Complete',
      'created_at': '2026-11-21T10:00:00Z', 'read_at': readAt,
    };
    for (final invalid in [true, 123, 'not-a-date']) {
      expect(
        () => MemberNotification.fromJson(notification(invalid)),
        throwsFormatException,
      );
    }
    expect(MemberNotification.fromJson(notification(null)).isRead, isFalse);
    expect(
      MemberNotification.fromJson(
        notification('2026-11-21T10:01:00Z'),
      ).isRead,
      isTrue,
    );
  });

  test('Missing notification fields fail closed', () {
    expect(() => MemberNotificationInbox.fromJson({
      'unread': 1, 'items': [{'title': 'Missing fields'}],
    }), throwsFormatException);
  });
}
