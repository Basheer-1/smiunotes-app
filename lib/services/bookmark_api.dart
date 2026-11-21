import 'dart:convert';
import 'dart:io';

/// A student bookmark always belongs to the verified server-side identity.
/// This client never stores bearer tokens, and never accepts user IDs.
class BookmarkApi {
  const BookmarkApi({required this.baseUrl});
  final String baseUrl;

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Uri get endpoint {
    final origin = Uri.tryParse(baseUrl);
    if (origin == null || origin.scheme != 'https' ||
        origin.host.isEmpty || origin.userInfo.isNotEmpty ||
        origin.hasQuery || origin.hasFragment) {
      throw const FormatException('Approved HTTPS API origin required.');
    }
    return origin.resolve('/api/mobile/v1/bookmarks');
  }

  String bearer(String token) {
    if (token.length < 30 || token.length > 4096 ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(token)) {
      throw const FormatException('Verified student sign-in required.');
    }
    return 'Bearer $token';
  }

  String checkedNoteId(String noteId) {
    if (!_uuid.hasMatch(noteId)) {
      throw const FormatException('Invalid note ID.');
    }
    return noteId;
  }

  Future<Map<String, dynamic>> list(String accessToken) =>
      _request(accessToken);

  Future<Map<String, dynamic>> save(String accessToken, String noteId) =>
      _request(accessToken, action: {
        'op': 'save', 'note_id': checkedNoteId(noteId),
      });

  Future<Map<String, dynamic>> remove(String accessToken, String noteId) =>
      _request(accessToken, action: {
        'op': 'remove', 'note_id': checkedNoteId(noteId),
      });

  Future<Map<String, dynamic>> _request(String accessToken,
      {Map<String, String>? action}) async {
    final url = endpoint;
    final authorization = bearer(accessToken);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = action == null
          ? await client.getUrl(url).timeout(const Duration(seconds: 12))
          : await client.postUrl(url).timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, authorization);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (action != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(action));
      }
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.ok) {
        // Do not include private response details in error messages.
        throw const HttpException('Bookmarks unavailable.');
      }
      const maxBytes = 131072;
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 12))) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('Bookmark response too large.');
        }
        bytes.addAll(chunk);
      }
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid bookmark response.');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}
