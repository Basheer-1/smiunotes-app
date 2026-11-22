import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/contributors_directory_page.dart';
import 'package:smiunotes_mobile/services/contributors_api.dart';

class FakeContributorsApi extends ContributorsApi {
  FakeContributorsApi() : super(baseUrl: 'https://smiunotes.com');
  String lastQuery = '';
  String lastSort = '';
  int lastPage = 0;

  @override
  Future<Map<String, dynamic>> fetch({
    String query = '', String department = '', String sort = 'notes',
    int page = 1, int departmentsPage = 1,
  }) async {
    lastQuery = query;
    lastSort = sort;
    lastPage = page;
    return {
      'page': page,
      'has_more': page == 1,
      'departments': <Map<String, dynamic>>[],
      'leaderboards': [
        {
          'id': 'aaa', 'name': 'Computer Science',
          'leaders': [
            {'id': 'bbb', 'name': 'Ayesha Contributor', 'rank': 1,
             'notes': 8, 'departments': ['Computer Science']},
          ],
        },
      ],
      'items': [
        {'id': 'bbb', 'name': 'Ayesha Contributor', 'notes': 8,
         'departments': ['Computer Science']},
      ],
    };
  }
}

void main() {
  test('Contributors request rejects untrusted API origins', () async {
    expect(() => ContributorsApi(baseUrl: 'http://example.com').fetch(),
      throwsA(isA<FormatException>()));
  });

  testWidgets('Native public contributors and rankings load without login',
      (tester) async {
    final api = FakeContributorsApi();
    await tester.pumpWidget(MaterialApp(
      home: ContributorsDirectoryPage(api: api),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Department Top 10'), findsOneWidget);
    expect(find.text('All Contributors'), findsOneWidget);
    expect(find.text('Computer Science'), findsWidgets);
    expect(find.text('Ayesha Contributor'), findsWidgets);
    expect(find.text('8 notes'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('contributor-search')));
    await tester.enterText(find.byKey(const Key('contributor-search')), 'Ayesha');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(api.lastQuery, 'Ayesha');
  });
}
