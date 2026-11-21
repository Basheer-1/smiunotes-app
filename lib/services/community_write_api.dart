import 'dart:convert';
import 'dart:io';

/// Calls the existing forum_post authorization and rate-limit rules through
/// the mobile API. Used only by a validated student session on staging.
class CommunityWriteApi {
  const CommunityWriteApi({required this.baseUrl});
  final String baseUrl;

  Future<String> createDiscussion({
    required String accessToken,
    required String title,
    required String message,
    required String category,
  }) async {
    if (title.trim().length < 3 || title.trim().length > 160 ||
        message.trim().length < 10 || message.trim().length > 6000 ||
        !const ['questions', 'study', 'announcements'].contains(category)) {
      throw const FormatException('Invalid discussion content.');
    }
    final result = await _post(accessToken, {
      'op': 'discussion', 'title': title.trim(),
      'body': message.trim(), 'category': category,
    });
    final id = result['id'];
    if (id is! String || !RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(id)) {
      throw const FormatException('Invalid discussion response.');
    }
    return id;
  }

  Future<void> reply({
    required String accessToken,
    required String threadId,
    required String message,
  }) async {
    if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(threadId) ||
        message.trim().isEmpty || message.trim().length > 3000) {
      throw const FormatException('Invalid reply.');
    }
    final result = await _post(accessToken, {
      'op': 'reply', 'thread': threadId, 'body': message.trim(),
    });
    if (result['posted'] != true) {
      throw const FormatException('Reply not confirmed.');
    }
  }

  Future<Map<String, dynamic>> _post(
    String token, Map<String, String> data,
  ) async {
    if (token.length < 30 || token.length > 4096 ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(token)) {
      throw const FormatException('Student sign-in required.');
    }
    final origin = Uri.tryParse(baseUrl);
    if (origin == null || origin.scheme != 'https' || origin.host.isEmpty ||
        origin.userInfo.isNotEmpty || origin.hasQuery || origin.hasFragment) {
      throw const FormatException('Configure an approved HTTPS API origin.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(
        origin.resolve('/api/mobile/v1/community'),
      ).timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(jsonEncode(data));
      final response = await request.close().timeout(
        const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.created) {
        throw const HttpException('Posting unavailable or restricted.');
      }
      final body = await utf8.decoder.bind(response).join().timeout(
        const Duration(seconds: 12));
      final result = jsonDecode(body);
      if (result is! Map<String, dynamic>) {
        throw const FormatException('Invalid response.');
      }
      return result;
    } finally {
      client.close(force: true);
    }
  }
}
