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

void main() {
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
}
