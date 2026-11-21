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


class SwitchingReaderApi extends PublicFeedApi {
  SwitchingReaderApi();
  final List<String> requested = [];

  @override
  Future<Map<String, dynamic>> fetchManifest(String noteId) async {
    requested.add(noteId);
    return {'title': 'Note $noteId', 'pages': <dynamic>[]};
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
  testWidgets('Changing note identity refreshes the public manifest',
      (tester) async {
    const first = '11111111-1111-4111-8111-111111111111';
    const second = '22222222-2222-4222-8222-222222222222';
    final api = SwitchingReaderApi();
    await tester.pumpWidget(MaterialApp(
      home: NoteReaderPage(noteId: first, api: api),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Note $first'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: NoteReaderPage(noteId: second, api: api),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Note $first'), findsNothing);
    expect(find.text('Note $second'), findsOneWidget);
    expect(api.requested, [first, second]);
  });

}
