import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/community_feed_page.dart';
import 'package:smiunotes_mobile/services/public_feed_api.dart';

class FakeCommunityApi extends PublicFeedApi {
  const FakeCommunityApi();

  @override
  Future<Map<String, dynamic>> fetchThread(String threadId, {int page = 1}) async {
    return {
      'thread': {'title': 'Study group', 'body': 'Full discussion body',
                 'category': 'study', 'author_name': 'Student', 'locked': false},
      'replies': [
        {'id': 'reply-1', 'body': 'Helpful reply', 'author_name': 'Classmate'},
      ],
      'has_more': false,
    };
  }
  @override
  Future<Map<String, dynamic>> fetch(
    String kind, {
    int page = 1,
    String search = '',
    String stream = '',
    String department = '',
    String semester = '',
    String subject = '',
    String category = '',
  }) async {
    return {
      'page': page,
      'has_more': false,
      'items': [
        {'id': 'discussion-1', 'title': 'Study group',
         'preview': 'Who is preparing for the exam?',
         'author_name': 'Student', 'replies': 3},
      ],
    };
  }
}

void main() {
  testWidgets('Read-only community feed shows discussions', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CommunityFeedPage(api: FakeCommunityApi())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Study group'), findsOneWidget);
    expect(find.textContaining('Who is preparing'), findsOneWidget);
    await tester.tap(find.text('Study group'));
    await tester.pumpAndSettle();
    expect(find.text('Full discussion body'), findsOneWidget);
    expect(find.text('Helpful reply'), findsOneWidget);
  });
}
