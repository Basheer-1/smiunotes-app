import 'dart:convert';
import 'dart:io';

/// Authorized mobile media adapter. Unused until native sign-in is reviewed.
/// No credentials are stored or logged in this class.
class AuthenticatedReaderApi {
  const AuthenticatedReaderApi({required this.baseUrl});
  final String baseUrl;

  Future<Map<String, dynamic>> request({
    required String accessToken,
    required String noteId,
    required bool manifest,
    int? page,
  }) async {
    if (accessToken.length < 30 || accessToken.length > 4096 ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(accessToken)) {
      throw const FormatException('Sign-in required.');
    }
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(noteId)) {
      throw const FormatException('Invalid note ID.');
    }
    if (!manifest && (page == null || page < 1 || page > 60)) {
      throw const FormatException('Invalid page number.');
    }
    final origin = Uri.tryParse(baseUrl);
    if (origin == null || origin.scheme != 'https' ||
        origin.host.isEmpty || origin.userInfo.isNotEmpty ||
        origin.hasQuery || origin.hasFragment) {
      throw const FormatException('Configure a trusted HTTPS API origin.');
    }
    final params = <String, String>{
      'op': manifest ? 'manifest' : 'page',
      'id': noteId,
      if (!manifest) 'page': '$page',
    };
    final url = origin.resolve('/api/mobile/v1/reader')
        .replace(queryParameters: params);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(url).timeout(
        const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.ok) {
        throw const HttpException('Reader unavailable.');
      }
      final raw = await utf8.decoder.bind(response).join().timeout(
        const Duration(seconds: 12));
      final payload = jsonDecode(raw);
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Invalid reader response.');
      }
      return payload;
    } finally {
      client.close(force: true);
    }
  }
}
