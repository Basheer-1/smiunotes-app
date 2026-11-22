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

class ExpiredApplyApi extends FakeApi {
  const ExpiredApplyApi();
  @override
  Future<Map<String, dynamic>> fetch(
    String kind, {int page = 1, String search = '', String stream = '',
    String department = '', String semester = '', String subject = '',
    String category = ''}) async {
    final result = await super.fetch(kind, page: page, search: search,
      stream: stream, department: department, semester: semester,
      subject: subject, category: category);
    if (kind == 'updates') {
      final update = Map<String, dynamic>.from(
        (result['items'] as List<dynamic>).first as Map<String, dynamic>);
      update['application_url'] = 'https://example.org/apply';
      update['deadline_date'] = '2020-01-01';
      result['items'] = [update];
    }
    return result;
  }
}

class RefreshingApi extends FakeApi {
  int notesCalls = 0;
  int updatesCalls = 0;
  @override
  Future<Map<String, dynamic>> fetch(
    String kind, {int page = 1, String search = '', String stream = '',
    String department = '', String semester = '', String subject = '',
    String category = ''}) async {
    if (kind == 'notes') {
      notesCalls++;
      return {'page': 1, 'total': notesCalls, 'items': [
        {'id': 'note-1', 'title': notesCalls == 1
          ? 'Original note' : 'Just published test note',
         'department_name': 'Computer Science', 'semester': 1},
      ]};
    }
    if (kind == 'updates') updatesCalls++;
    return super.fetch(kind, page: page, search: search, stream: stream,
      department: department, semester: semester, subject: subject,
      category: category);
  }
}

class CapturingApi extends FakeApi {
  String lastCategory = '';
  String lastStream = '';
  @override
  Future<Map<String, dynamic>> fetch(
    String kind, {int page = 1, String search = '', String stream = '',
    String department = '', String semester = '', String subject = '',
    String category = ''}) async {
    if (kind == 'updates') {
      lastCategory = category;
      lastStream = stream;
    }
    return super.fetch(kind, page: page, search: search, stream: stream,
      department: department, semester: semester, subject: subject,
      category: category);
  }
}

void main() {
  testWidgets('Updates category filter is sent to the API', (tester) async {
    final api = CapturingApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PublicFeedPage(type: 'updates', api: api)),
    ));
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('update-category-'));
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scholarships').last);
    await tester.pumpAndSettle();
    expect(api.lastCategory, 'scholarships');

    final campusChip = find.byKey(const Key('update-stream-campus'));
    await tester.ensureVisible(campusChip);
    await tester.tap(campusChip);
    await tester.pumpAndSettle();
    expect(api.lastStream, 'campus');
    expect(api.lastCategory, isEmpty);
  });

  testWidgets('Expired application is disabled on card and detail',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PublicFeedPage(
        type: 'updates', api: ExpiredApplyApi())),
    ));
    await tester.pumpAndSettle();
    final cardButton = find.byKey(const Key('update-apply-update-1'));
    await tester.ensureVisible(cardButton);
    expect(tester.widget<FilledButton>(cardButton).onPressed, isNull);
    expect(find.text('Applications Closed'), findsOneWidget);
    await tester.ensureVisible(find.text('Exam timetable'));
    await tester.tap(find.text('Exam timetable'));
    await tester.pumpAndSettle();
    final detail = find.byKey(const Key('update-apply-now-detail'));
    await tester.ensureVisible(detail);
    expect(tester.widget<FilledButton>(detail).onPressed, isNull);
  });

  testWidgets('Updates card displays Upcoming status for future event',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PublicFeedPage(type: 'updates', api: FakeApi())),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('update-status-upcoming')), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
  });

  testWidgets('Manual refresh fetches newly published notes without restart',
      (tester) async {
    final api = RefreshingApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PublicFeedPage(type: 'notes', api: api)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Original note'), findsOneWidget);
    final refresh = find.byKey(const Key('feed-refresh-button-notes'));
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(find.text('Just published test note'), findsOneWidget);
    expect(api.notesCalls, 2);
  });

  testWidgets('Returning to a feed triggers a new fetch',
      (tester) async {
    final api = RefreshingApi();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: PublicFeedPage(type: 'notes', api: api, refreshVersion: 0),
    )));
    await tester.pumpAndSettle();
    expect(api.notesCalls, 1);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: PublicFeedPage(type: 'notes', api: api, refreshVersion: 1),
    )));
    await tester.pumpAndSettle();
    expect(api.notesCalls, 2);
    expect(find.text('Just published test note'), findsOneWidget);
  });

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

  testWidgets('Changing feed kind clears search from the previous tab',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PublicFeedPage(type: 'updates', api: FakeApi())),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('search-updates')), 'exam');
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PublicFeedPage(type: 'notes', api: FakeApi())),
    ));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const Key('search-notes')),
    );
    expect(field.controller!.text, isEmpty);
    expect(field.maxLength, 100);
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
