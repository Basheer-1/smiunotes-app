import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/my_bookmarks_page.dart';
import 'package:smiunotes_mobile/services/bookmark_api.dart';

class FakeBookmarks extends BookmarkApi {
  FakeBookmarks() : super(baseUrl: 'https://smiunotes.com');
  bool removed = false;
  final tokens = <String>[];

  @override
  Future<Map<String, dynamic>> list(String accessToken) async {
    tokens.add(accessToken);
    return {
      'items': removed ? <dynamic>[] : [
        {'note_id': '11111111-1111-4111-8111-111111111111',
         'title': 'Programming Notes',
         'created_at': '2026-11-21T00:00:00Z'}
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> remove(String accessToken, String noteId) async {
    tokens.add(accessToken);
    removed = true;
    return {'ok': true, 'bookmarked': false};
  }
}

void main() {
  testWidgets('saved notes show title and removal refreshes listing', (tester) async {
    final api = FakeBookmarks();
    var generation = 0;
    await tester.pumpWidget(MaterialApp(home: MyBookmarksPage(
      api: api, currentAccessToken: () => 'token-${++generation}',
    )));
    await tester.pumpAndSettle();
    expect(find.text('Programming Notes'), findsOneWidget);
    await tester.tap(find.byKey(const Key(
      'remove-bookmark-11111111-1111-4111-8111-111111111111')));
    await tester.pumpAndSettle();
    expect(find.text('No bookmarked notes yet.'), findsOneWidget);
    expect(api.tokens.length, 3);
    expect(api.tokens[0], isNot(api.tokens[1]));
  });

  testWidgets('unavailable saved notes fail closed', (tester) async {
    final api = FakeBookmarks();
    await tester.pumpWidget(MaterialApp(home: MyBookmarksPage(
      api: api,
      currentAccessToken: () => throw StateError('Signed out'),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to load saved notes.'), findsOneWidget);
    expect(find.text('Programming Notes'), findsNothing);
  });
}
