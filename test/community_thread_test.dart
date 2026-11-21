import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/community_thread_page.dart';
import 'package:smiunotes_mobile/services/public_feed_api.dart';

class FakeThreadApi extends PublicFeedApi {
  const FakeThreadApi();

  @override
  Future<Map<String, dynamic>> fetchThread(String threadId, {int page = 1}) async {
    return {
      'thread': {
        'id': threadId,
        'title': 'Semester planning discussion',
        'body': 'Which subjects should we revise first?',
        'author_name': 'Student',
        'category': 'study',
        'locked': false,
      },
      'page': page,
      'has_more': false,
      'replies': [
        {'id': 'reply-1', 'body': 'Start with programming.',
         'author_name': 'Classmate'},
      ],
    };
  }
}


class _SwitchingThreadApi extends PublicFeedApi {
  const _SwitchingThreadApi(this.loader);
  final Future<Map<String, dynamic>> Function(String, {int page}) loader;
  @override
  Future<Map<String, dynamic>> fetchThread(String threadId, {int page = 1}) =>
      loader(threadId, page: page);
}


void main() {
  testWidgets('Verified callback is used for unlocked thread replies', (tester) async {
    String? received;
    await tester.pumpWidget(MaterialApp(
      home: CommunityThreadPage(
        threadId: '11111111-1111-4111-8111-111111111111',
        api: const FakeThreadApi(),
        onReply: (thread) async { received = thread; return true; },
      ),
    ));
    await tester.pumpAndSettle();
    final reply = find.byKey(const Key('community-reply-button'));
    await tester.ensureVisible(reply);
    await tester.tap(reply);
    await tester.pumpAndSettle();
    expect(received, '11111111-1111-4111-8111-111111111111');
  });

  testWidgets('Locked discussion hides the reply action', (tester) async {
    Future<Map<String, dynamic>> locked(String id, {int page = 1}) async => {
      'thread': {'id': id, 'title': 'Locked discussion',
        'body': 'Staff locked this thread', 'locked': true},
      'replies': <dynamic>[], 'has_more': false,
    };
    await tester.pumpWidget(MaterialApp(
      home: CommunityThreadPage(
        threadId: '11111111-1111-4111-8111-111111111111',
        api: _SwitchingThreadApi(locked),
        onReply: (thread) async => true,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-reply-button')), findsNothing);
    expect(find.textContaining('Replies are disabled'), findsOneWidget);
  });

  testWidgets('Renders public discussion and replies without auth', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CommunityThreadPage(
        threadId: '11111111-1111-4111-8111-111111111111',
        api: FakeThreadApi(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Semester planning discussion'), findsOneWidget);
    expect(find.text('Which subjects should we revise first?'), findsOneWidget);
    expect(find.text('Start with programming.'), findsOneWidget);
    expect(find.byKey(const Key('thread-detail')), findsOneWidget);
  });
  testWidgets('Changing discussion ID replaces old thread content',
      (tester) async {
    var calls = 0;
    Future<Map<String, dynamic>> load(String id, {int page = 1}) async {
      calls++;
      return {
        'thread': {
          'title': id == 'thread-a' ? 'Old discussion' : 'New discussion',
          'body': 'The current discussion body',
          'author_name': 'Student',
        },
        'replies': <dynamic>[],
        'has_more': false,
      };
    }
    final api = _SwitchingThreadApi(load);
    await tester.pumpWidget(MaterialApp(
      home: CommunityThreadPage(threadId: 'thread-a', api: api),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Old discussion'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
      home: CommunityThreadPage(threadId: 'thread-b', api: api),
    ));
    await tester.pumpAndSettle();
    expect(find.text('New discussion'), findsOneWidget);
    expect(find.text('Old discussion'), findsNothing);
    expect(calls, 2);
  });

}
