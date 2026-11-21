import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/authenticated_note_reader_page.dart';

void main() {
  const id = '11111111-1111-4111-8111-111111111111';
  const token = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  testWidgets('Protected manifest must load before revealing note title',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: AuthenticatedNoteReaderPage(
        noteId: id,
        accessToken: token,
        request: ({
          required String accessToken,
          required String noteId,
          required bool manifest,
          int? page,
        }) async {
          calls++;
          expect(accessToken, token);
          expect(noteId, id);
          expect(manifest, true);
          return {'title': 'Verified QA notes', 'pages': <dynamic>[]};
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Verified QA notes'), findsOneWidget);
    expect(find.byKey(const Key('authenticated-note-reader')), findsOneWidget);
  });

  testWidgets('Reader fails closed when authorization fails', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthenticatedNoteReaderPage(
        noteId: id,
        accessToken: token,
        request: ({
          required String accessToken,
          required String noteId,
          required bool manifest,
          int? page,
        }) async => throw StateError('403: not verified'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('verification has expired'), findsOneWidget);
    expect(find.text('Verified QA notes'), findsNothing);
  });
}
