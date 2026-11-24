import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/note_reader_page.dart';
import 'package:smiunotes_mobile/services/public_feed_api.dart';
import 'package:smiunotes_mobile/widgets/reader_toolbar_actions.dart';

class _ReaderApi extends PublicFeedApi {
  const _ReaderApi();
  @override
  Future<Map<String, dynamic>> fetchManifest(String noteId) async => {
    'title': 'Test reader',
    'pages': <dynamic>[],
  };
}

void main() {
  testWidgets('reader titlebar shows guest study controls and verified-only download',
      (tester) async {
    var promptCount = 0;
    await tester.pumpWidget(MaterialApp(home: NoteReaderPage(
      noteId: '11111111-1111-4111-8111-111111111111',
      api: const _ReaderApi(),
      toolbarActions: ReaderToolbarActions(
        loadState: () async => {'bookmarked': false, 'completed': false},
        toggleBookmark: (_) async { promptCount++; return false; },
        toggleCompleted: (_) async { promptCount++; return false; },
        onDownloadUnavailable: () { promptCount++; },
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader-bookmark')), findsOneWidget);
    expect(find.byKey(const Key('reader-completed')), findsOneWidget);
    expect(find.byKey(const Key('reader-offline-download')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reader-bookmark')));
    await tester.pumpAndSettle();
    expect(promptCount, 1);
  });
}
