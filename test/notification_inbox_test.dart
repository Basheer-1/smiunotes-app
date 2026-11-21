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
  test('Missing notification fields fail closed', () {
    expect(() => MemberNotificationInbox.fromJson({
      'unread': 1, 'items': [{'title': 'Missing fields'}],
    }), throwsFormatException);
  });
}
