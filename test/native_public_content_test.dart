import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smiunotes_mobile/screens/native_public_content_page.dart';

void main() {
  for (final kind in ['about', 'privacy', 'disclaimer']) {
    testWidgets('$kind public information displays natively without login',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NativePublicContentPage(kind: kind),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('native-public-content-$kind')), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(SelectableText), findsWidgets);
      // No WebView is imported into the public-content feature.
    });
  }
  testWidgets('privacy content covers account, card and support disclosure',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NativePublicContentPage(kind: 'privacy'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Student verification and profile'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Optional website support'), 180);
    expect(find.text('Optional website support'), findsOneWidget);
  });
}
