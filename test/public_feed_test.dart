import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/public_feed_page.dart';
import 'package:smiunotes_mobile/services/public_feed_api.dart';

class FakeApi extends PublicFeedApi {
  const FakeApi();
  @override
  Future<Map<String, dynamic>> fetchManifest(String noteId) async {
    if (noteId != 'note-1') throw StateError('Unexpected note');
    return {
      'title': 'Reader uses injected API',
      'description': 'Configured staging backend was preserved.',
      'pages': <dynamic>[],
    };
  }

  @override
  Future<Map<String, dynamic>> fetch(
    String kind, {int page = 1, String search = '', String stream = '',
    String department = '', String semester = '', String subject = '', String category = ''}) async {
    if (kind == 'filters') {
      return {
        'departments': [
          {'id': 'department-1', 'name': 'Computer Science'},
        ],
        'semesters': [1],
        'subjects': [
          {'id': 'subject-1', 'department_id': 'department-1',
           'semester': 1, 'code': 'CSC101', 'name': 'Programming'},
        ],
      };
    }
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
    expect(find.textContaining('Computer Science'), findsWidgets);
    expect(find.byKey(const Key('department-filter')), findsOneWidget);
    expect(find.byKey(const Key('subject-filter')), findsOneWidget);
  });

  testWidgets('Updates feed shows published announcement', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PublicFeedPage(type: 'updates', api: FakeApi())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Exam timetable'), findsOneWidget);
    expect(find.text('Schedule announcement'), findsOneWidget);
  });
  testWidgets('Catalogue note viewer uses the same configured API',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PublicFeedPage(type: 'notes', api: FakeApi())),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Introduction to Programming'));
    await tester.tap(find.text('Introduction to Programming'));
    await tester.pumpAndSettle();
    expect(find.text('Reader uses injected API'), findsOneWidget);
    expect(find.text('Configured staging backend was preserved.'),
      findsOneWidget);
  });

}
