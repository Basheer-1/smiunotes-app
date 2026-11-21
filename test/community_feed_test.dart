import 'dart:async';
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

class DelayedCommunityApi extends PublicFeedApi {
  DelayedCommunityApi();
  final requests = <String, Completer<Map<String, dynamic>>>{};

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
  }) {
    final pending = Completer<Map<String, dynamic>>();
    requests[category] = pending;
    return pending.future;
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
  testWidgets('Slow old category response cannot overwrite the new feed',
      (tester) async {
    final api = DelayedCommunityApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CommunityFeedPage(api: api)),
    ));
    await tester.pump();
    await tester.tap(find.text('Study'));
    await tester.pump();
    api.requests['study']!.complete({
      'has_more': false,
      'items': [
        {'id': 'new-discussion', 'title': 'Current study posts',
         'preview': 'New content', 'author_name': 'Student', 'replies': 0},
      ],
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('Current study posts'), findsOneWidget);
    api.requests['']!.complete({
      'has_more': false,
      'items': [
        {'id': 'stale-discussion', 'title': 'Old response',
         'preview': 'Old content', 'author_name': 'Student', 'replies': 0},
      ],
    });
    await tester.pumpAndSettle();
    expect(find.text('Current study posts'), findsOneWidget);
    expect(find.text('Old response'), findsNothing);
  });

}
