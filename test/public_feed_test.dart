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
          {'id': 'department-2', 'name': 'Software Engineering'},
        ],
        'semesters': [1, 2],
        'subjects': [
          {'id': 'subject-1', 'department_id': 'department-1',
           'semester': 1, 'code': 'CSC101', 'name': 'Programming'},
          {'id': 'subject-2', 'department_id': 'department-2',
           'semester': 2, 'code': 'SWE201', 'name': 'Software Design'},
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
          'body': 'Exams start soon',
          'category': 'inside',
          'event_date': '2026-12-01',
          'deadline_date': '2026-11-29',
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
    await tester.tap(find.text('Exam timetable'));
    await tester.pumpAndSettle();
    expect(find.text('Exams start soon'), findsOneWidget);
    expect(find.text('Category: inside'), findsOneWidget);
    expect(find.text('Event: 2026-12-01'), findsOneWidget);
    expect(find.text('Deadline: 2026-11-29'), findsOneWidget);
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

  testWidgets('Switching Updates to Notes refreshes content and filters',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PublicFeedPage(type: 'updates', api: FakeApi())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Exam timetable'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PublicFeedPage(type: 'notes', api: FakeApi())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Introduction to Programming'), findsOneWidget);
    expect(find.text('Exam timetable'), findsNothing);
    expect(find.byKey(const Key('department-filter')), findsOneWidget);
  });

  testWidgets('Changing department resets selected Semester and Subject',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PublicFeedPage(type: 'notes', api: FakeApi())),
    ));
    await tester.pumpAndSettle();

    final semesterBefore = find.byKey(const ValueKey('semester-'));
    await tester.ensureVisible(semesterBefore);
    await tester.tap(semesterBefore);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semester 1').last);
    await tester.pumpAndSettle();

    final subjectBefore = find.byKey(const ValueKey('subject--1'));
    await tester.ensureVisible(subjectBefore);
    await tester.tap(subjectBefore);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('CSC101').last);
    await tester.pumpAndSettle();

    final departmentDropdown = find.descendant(
      of: find.byKey(const Key('department-filter')),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.ensureVisible(departmentDropdown);
    await tester.tap(departmentDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Software Engineering').last);
    await tester.pumpAndSettle();

    final resetSemester = find.byKey(const ValueKey('semester-department-2'));
    expect(resetSemester, findsOneWidget);
    expect(tester.state<FormFieldState<String>>(resetSemester).value, '');
    final resetSubject = find.byKey(
      const ValueKey('subject-department-2-'),
    );
    expect(resetSubject, findsOneWidget);
    expect(tester.state<FormFieldState<String>>(resetSubject).value, '');
    expect(
      find.descendant(
        of: find.byKey(const Key('subject-filter')),
        matching: find.textContaining('CSC101'),
      ),
      findsNothing,
    );
  });

}
