import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/main.dart';

void main() {
  testWidgets('M1 loads home and navigates to Notes and Updates', (tester) async {
    await tester.pumpWidget(const SmiuNotesApp());

    expect(find.text('Everything SMIU,\nin one place.'), findsOneWidget);
    expect(find.byKey(const Key('home-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('explore-notes')));
    await tester.pumpAndSettle();
    expect(find.text('Browse notes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('University updates'), findsOneWidget);
  });
}
