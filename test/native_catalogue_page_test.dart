import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/native_catalogue_page.dart';
import 'package:smiunotes_mobile/services/public_feed_api.dart';

class _FakeCatalogueApi extends PublicFeedApi {
  const _FakeCatalogueApi();

  @override
  Future<Map<String, dynamic>> fetch(String kind, {
    int page = 1,
    String search = '',
    String stream = '',
    String department = '',
    String semester = '',
    String subject = '',
    String category = '',
  }) async {
    if (kind == 'filters') {
      return {
        'departments': [
          {'id': 'cs', 'name': 'Computer Science'},
          {'id': 'empty', 'name': 'Not Published Yet'},
        ],
        'semesters': [1, 2],
        'subjects': [
          {'id': 'math', 'department_id': 'cs', 'semester': 1,
           'code': 'MTH101', 'name': 'Calculus'},
        ],
      };
    }
    return {'items': [], 'total': 0};
  }
}

void main() {
  testWidgets('catalogue excludes departments with no published subjects',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NativeCataloguePage(api: _FakeCatalogueApi()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Computer Science'), findsOneWidget);
    expect(find.text('Not Published Yet'), findsNothing);
    expect(find.byKey(const Key('browse-semester-1')), findsOneWidget);
  });

  testWidgets('department expands into published semesters only',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NativeCataloguePage(api: _FakeCatalogueApi()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Computer Science'));
    await tester.pumpAndSettle();

    expect(find.text('Semester 1'), findsNWidgets(2));
    expect(find.text('Semester 2'), findsOneWidget);
  });
}
