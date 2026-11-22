import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smiunotes_mobile/screens/native_notification_preferences_page.dart';

void main() {
  testWidgets('University alerts are loaded from server and saved per account',
      (tester) async {
    bool serverValue = true;
    final writes = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: NativeNotificationPreferencesPage(
        load: () async => serverValue,
        save: (value) async {
          writes.add(value);
          serverValue = value;
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notify-updates-toggle')), findsOneWidget);
    expect(find.text('Newly published notes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notify-updates-toggle')));
    await tester.pumpAndSettle();
    expect(writes, [false]);
    expect(serverValue, isFalse);
  });

  testWidgets('Server rejection does not alter the stored UI preference',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NativeNotificationPreferencesPage(
        load: () async => true,
        save: (_) async => throw StateError('fail closed'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notify-updates-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('preference-error')), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('notify-updates-toggle')));
    expect(toggle.value, isTrue);
  });
}
