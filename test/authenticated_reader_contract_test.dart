import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/services/authenticated_reader_api.dart';

void main() {
  const api = AuthenticatedReaderApi(baseUrl: 'https://staging.example.com');

  test('rejects missing session and malformed IDs without a network call', () async {
    await expectLater(
      api.request(
        accessToken: '', noteId: '11111111-1111-4111-8111-111111111111',
        manifest: true,
      ), throwsFormatException,
    );
    await expectLater(
      api.request(
        accessToken: 'a' * 64, noteId: 'not-a-uuid',
        manifest: true,
      ), throwsFormatException,
    );
  });

  test('rejects invalid page numbers before requesting a signed URL', () async {
    for (final page in [0, 61]) {
      await expectLater(
        api.request(
          accessToken: 'a' * 64,
          noteId: '11111111-1111-4111-8111-111111111111',
          manifest: false,
          page: page,
        ),
        throwsFormatException,
      );
    }
  });

  test('does not accept HTTP base URLs', () async {
    const insecure = AuthenticatedReaderApi(baseUrl: 'http://example.com');
    await expectLater(
      insecure.request(
        accessToken: 'a' * 64,
        noteId: '11111111-1111-4111-8111-111111111111',
        manifest: true,
      ),
      throwsFormatException,
    );
  });
}
