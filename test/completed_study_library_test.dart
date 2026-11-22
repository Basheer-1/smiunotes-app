import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/services/bookmark_api.dart';
import 'package:smiunotes_mobile/screens/my_bookmarks_page.dart';

class FakeStudyLibrary extends BookmarkApi {
  FakeStudyLibrary() : super(baseUrl: 'https://smiunotes.com');
  bool completed = true;
  final seen = <String>[];

  @override
  Future<Map<String, dynamic>> list(String token) async {
    seen.add('bookmarks:$token');
    return {'items': [
      {'note_id': '11111111-1111-4111-8111-111111111111',
       'title': 'Notes A', 'saved': true, 'completed': completed},
    ]};
  }
  @override
  Future<Map<String, dynamic>> listCompleted(String token) async {
    seen.add('completed:$token');
    return {'items': completed ? [
      {'note_id': '11111111-1111-4111-8111-111111111111',
       'title': 'Notes A', 'saved': true, 'completed': true},
    ] : <dynamic>[]};
  }
  @override
  Future<Map<String, dynamic>> complete(String token, String id) async {
    seen.add('complete:$token');
    completed = true;
    return {'ok': true, 'completed': true};
  }
  @override
  Future<Map<String, dynamic>> uncomplete(String token, String id) async {
    seen.add('uncomplete:$token');
    completed = false;
    return {'ok': true, 'completed': false};
  }
}

void main() {
  testWidgets('Completed notes can be viewed and unmarked independently',
      (tester) async {
    final api = FakeStudyLibrary();
    await tester.pumpWidget(MaterialApp(home: MyBookmarksPage(
      api: api, currentAccessToken: () => 'validated-session-token',
    )));
    await tester.pumpAndSettle();
    expect(find.text('Notes A'), findsOneWidget);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(api.seen.last, startsWith('completed:'));
    expect(find.text('Completed note'), findsOneWidget);
    await tester.tap(find.byKey(const Key(
      'uncomplete-note-11111111-1111-4111-8111-111111111111')));
    await tester.pumpAndSettle();
    expect(find.text('No completed notes yet.'), findsOneWidget);
    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();
    expect(find.text('Notes A'), findsOneWidget);
    expect(api.seen.where((x) => x.startsWith('uncomplete:')).length, 1);
    await tester.tap(find.byKey(const Key(
      'toggle-completed-11111111-1111-4111-8111-111111111111')));
    await tester.pumpAndSettle();
    expect(api.completed, isTrue);
    expect(api.seen.last, startsWith('bookmarks:'));
    expect(api.seen.where((x) => x.startsWith('complete:')).length, 1);
  });
}
