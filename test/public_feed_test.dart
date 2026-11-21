import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/public_feed_page.dart';
import 'package:smiunotes_mobile/services/public_feed_api.dart';

class FakeApi extends PublicFeedApi {
  const FakeApi();
  @override
  Future<Map<String, dynamic>> fetch(
    String kind, {int page = 1, String search = '', String stream = '',
    String department = '', String semester = ''}) async {
    if (kind == 'notes') {
      return {
        'page': page, 'total': 1,
        'items': [
          {
            'id': 'note-1', 'title': 'Introduction to Programming',
            'department_name': 'Computer Science',
            'subject_code': 'CSC101', 'semester': 1, 'is_sensitive': false,
          },
        ],
      };
    }
    return {
      'page': page, 'total': 1,
      'items': [
        {
          'id': 'update-1', 'title': 'Exam timetable',
          'summary': 'Schedule announcement',
        },
      ],
    };
  }
}

void main() {
  testWidgets('Notes feed displays published metadata', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PublicFeedPage(type: 'notes', api: FakeApi())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Introduction to Programming'), findsOneWidget);
    expect(find.textContaining('Computer Science'), findsOneWidget);
  });

  testWidgets('Updates feed shows published announcement', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PublicFeedPage(type: 'updates', api: FakeApi())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Exam timetable'), findsOneWidget);
    expect(find.text('Schedule announcement'), findsOneWidget);
  });
}
