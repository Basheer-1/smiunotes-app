import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/note_reader_page.dart';
import 'package:smiunotes_mobile/services/public_feed_api.dart';

class FakeReaderApi extends PublicFeedApi {
  const FakeReaderApi();

  @override
  Future<Map<String, dynamic>> fetchManifest(String noteId) async {
    return {
      'title': 'Sample Published Note',
      'description': 'Read online only.',
      'pageCount': 0,
      'pages': <Map<String, dynamic>>[],
    };
  }
}

void main() {
  testWidgets('Public note reader displays authorized manifest metadata', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NoteReaderPage(
        noteId: '11111111-1111-4111-8111-111111111111',
        api: FakeReaderApi(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sample Published Note'), findsOneWidget);
    expect(find.text('Read online only.'), findsOneWidget);
    expect(find.byKey(const Key('note-reader')), findsOneWidget);
  });
}
