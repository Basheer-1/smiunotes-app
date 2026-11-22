import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/native_notification_preferences_page.dart';
import 'package:smiunotes_mobile/services/mobile_preferences_api.dart';

class FakePreferencesApi extends MobilePreferencesApi {
  FakePreferencesApi() : super(baseUrl: 'https://example.com');
  bool updates = true;
  int saves = 0;

  @override
  Future<bool> load(String token) async => updates;

  @override
  Future<bool> save(String token, bool enabled) async {
    saves++;
    updates = enabled;
    return updates;
  }
}

void main() {
  testWidgets('only optional university updates can be turned off',
      (tester) async {
    final api = FakePreferencesApi();
    await tester.pumpWidget(MaterialApp(
      home: NativeNotificationPreferencesPage(
        api: api,
        currentAccessToken: () => 'test-token',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Essential account alerts'), findsOneWidget);
    expect(find.text('Every new note published'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);

    await tester.tap(find.byKey(const Key('notify-university-updates')));
    await tester.pumpAndSettle();
    expect(api.saves, 1);
    expect(api.updates, isFalse);
  });
}
