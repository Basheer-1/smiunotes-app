import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smiunotes_mobile/models/member_notification.dart';
import 'package:smiunotes_mobile/screens/notification_inbox_page.dart';

void main() {
  testWidgets('expired session blocks refresh without contacting student API',
      (tester) async {
    String? currentToken = 'staging-test-token';
    var backendRequests = 0;

    Future<MemberNotificationInbox> load() async {
      if (currentToken == null) {
        throw StateError('Student sign-in required.');
      }
      backendRequests++;
      return const MemberNotificationInbox(items: [], unread: 0);
    }

    await tester.pumpWidget(MaterialApp(
      home: NotificationInboxPage(loader: load),
    ));
    await tester.pumpAndSettle();
    expect(backendRequests, 1);
    expect(find.byKey(const Key('notifications-empty')), findsOneWidget);

    currentToken = null;
    await tester.tap(find.byKey(const Key('notifications-refresh')));
    await tester.pumpAndSettle();
    expect(backendRequests, 1);
    expect(find.text('Unable to load notifications. Please retry.'), findsOneWidget);
  });
}
