import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/services/bookmark_api.dart';

void main() {
  const validId = '11111111-1111-4111-8111-111111111111';
  test('bookmarks route uses the configured production HTTPS origin', () {
    final api = BookmarkApi(baseUrl: 'https://smiunotes.com');
    expect(api.endpoint.toString(), 'https://smiunotes.com/api/mobile/v1/bookmarks');
    expect(api.checkedNoteId(validId), validId);
  });

  test('rejects untrusted origins without network access', () {
    for (final invalid in [
      '', 'http://smiunotes.com', 'https://user:password@smiunotes.com',
      'https://smiunotes.com?token=abc', 'https://smiunotes.com/#secret',
    ]) {
      expect(() => BookmarkApi(baseUrl: invalid).endpoint,
        throwsFormatException);
    }
  });

  test('rejects malformed identifiers and access tokens', () {
    final api = BookmarkApi(baseUrl: 'https://smiunotes.com');
    for (final invalid in ['', 'not-a-uuid', '11111111-1111']) {
      expect(() => api.checkedNoteId(invalid), throwsFormatException);
    }
    for (final invalid in ['', 'short', 'bearer\nattack']) {
      expect(() => api.bearer(invalid), throwsFormatException);
    }
    expect(api.bearer('x' * 40), 'Bearer ${'x' * 40}');
  });
}
