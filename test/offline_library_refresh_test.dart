import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smiunotes_mobile/screens/offline_library_page.dart';
import 'package:smiunotes_mobile/services/offline_notes_store.dart';

class _FakeOfflineStore extends OfflineNotesStore {
  _FakeOfflineStore() : super(baseUrl: 'https://example.test');

  @override
  Future<List<Map<String, dynamic>>> list(String owner) async {
    return [];
  }
}

void main() {
  testWidgets('offline library initializes and refreshes without async setState',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OfflineLibraryPage(
        store: _FakeOfflineStore(),
        owner: '11111111-1111-4111-8111-111111111111',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Offline Library'), findsOneWidget);
    expect(find.textContaining('No offline notes yet'), findsOneWidget);
    await tester.tap(find.byTooltip('Refresh offline library'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
