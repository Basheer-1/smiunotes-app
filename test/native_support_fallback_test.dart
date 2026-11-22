import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/screens/native_student_forms.dart';
import 'package:smiunotes_mobile/services/native_student_forms_api.dart';

class _MissingSupportApi extends NativeStudentFormsApi {
  const _MissingSupportApi()
    : super(baseUrl: 'https://smiunotes.com', tokenProvider: null);
  @override
  Future<Map<String, dynamic>> supportOptions({bool signedIn = true}) async {
    throw const NativeSupportNotAvailable();
  }
}

void main() {
  testWidgets('unavailable native support shows official website fallback',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NativeSupportFormPage(
        api: _MissingSupportApi(), signedIn: false),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-unavailable-message')), findsOneWidget);
    expect(find.byKey(const Key('support-website-fallback')), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
