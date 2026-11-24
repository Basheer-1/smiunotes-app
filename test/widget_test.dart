import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/main.dart';

void main() {
  testWidgets('M1 loads home and navigates to Notes and Updates', (tester) async {
    await tester.pumpWidget(const SmiuNotesApp());

    expect(find.text('Study Notes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-classic-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-page')), findsOneWidget);
    expect(find.textContaining('Preview mode:'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Study Notes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('Campus Updates'), findsOneWidget);
  });
  testWidgets('Guest bell opens restricted notifications preview', (tester) async {
    await tester.pumpWidget(const SmiuNotesApp());
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notifications-auth-required')), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
  });
}
