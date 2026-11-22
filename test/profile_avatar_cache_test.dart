import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/widgets/profile_avatar.dart';

void main() {
  test('initials fallback uses the first two name components', () {
    expect(ProfileAvatar.initials('Muhammad Basheer'), 'MB');
    expect(ProfileAvatar.initials(''), '?');
  });

  testWidgets('avatar is not fetched again when parent rebuilds',
      (tester) async {
    var calls = 0;
    Future<Uint8List?> loader() async {
      calls++;
      return null;
    }

    Widget avatar(String version) => MaterialApp(
          home: Scaffold(
            body: ProfileAvatar(
              name: 'Muhammad Basheer',
              cacheKey: 'student-1:$version',
              imageLoader: () => loader(),
            ),
          ),
        );

    await tester.pumpWidget(avatar('v1'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('MB'), findsOneWidget);

    // A fresh callback on an ordinary rebuild should not refetch the image.
    await tester.pumpWidget(avatar('v1'));
    await tester.pumpAndSettle();
    expect(calls, 1);

    // The backend avatar version changes after photo replacement.
    await tester.pumpWidget(avatar('v2'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
