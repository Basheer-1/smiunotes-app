import 'dart:convert';
import 'dart:io';

/// Configurable via --dart-define=SMIUNOTES_API_BASE=https://staging.example.com
/// Never embed server-side secrets in a mobile client.
class PublicFeedApi {
  const PublicFeedApi({this.baseUrl = const String.fromEnvironment(
    'SMIUNOTES_API_BASE',
    defaultValue: '',
  )});

  final String baseUrl;

  Uri _base() {
    final origin = Uri.tryParse(baseUrl);
    if (origin == null || origin.scheme != 'https' || origin.host.isEmpty ||
        origin.userInfo.isNotEmpty || origin.hasQuery || origin.hasFragment) {
      throw const FormatException('Configure an HTTPS staging API base URL.');
    }
    return origin;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 12));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Request failed: HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid API response.');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> fetchThread(String threadId, {int page = 1}) {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(threadId) ||
        page < 1 || page > 999) {
      throw const FormatException('Invalid discussion request.');
    }
    return _getJson(_base().resolve('/api/mobile/v1').replace(
      queryParameters: {'kind': 'thread', 'id': threadId, 'page': '$page'},
    ));
  }
  Future<Map<String, dynamic>> fetchManifest(String noteId) {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(noteId)) {
      throw const FormatException('Invalid note ID.');
    }
    return _getJson(
      _base().resolve('/api/mobile/v1').replace(
        queryParameters: {'kind': 'manifest', 'id': noteId},
      ),
    );
  }

  Future<String> fetchSignedPageUrl(String noteId, int page) async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(noteId) || page < 1 || page > 60) {
      throw const FormatException('Invalid note page.');
    }
    final data = await _getJson(
      _base().resolve('/api/notes/$noteId/pages/$page'),
    );
    final url = Uri.tryParse(data['url']?.toString() ?? '');
    if (url == null || url.scheme != 'https' || url.userInfo.isNotEmpty) {
      throw const FormatException('Invalid signed image URL.');
    }
    return url.toString();
  }

  Future<Map<String, dynamic>> fetch(
    String kind, {
    int page = 1,
    String search = '',
    String stream = '',
    String department = '',
    String semester = '',
    String subject = '',
    String category = '',
  }) async {
    final origin = Uri.tryParse(baseUrl);
    if (origin == null || origin.scheme != 'https' || origin.host.isEmpty ||
        origin.userInfo.isNotEmpty || origin.hasQuery || origin.hasFragment) {
      throw const FormatException('Configure an HTTPS staging API base URL.');
    }
    final params = <String, String>{'kind': kind};
    if (page > 1) params['page'] = '$page';
    if (search.trim().isNotEmpty) params['q'] = search.trim();
    if (stream.isNotEmpty) params['stream'] = stream;
    if (department.isNotEmpty) params['department'] = department;
    if (semester.isNotEmpty) params['semester'] = semester;
    if (subject.isNotEmpty) params['subject'] = subject;
    if (category.isNotEmpty) params['category'] = category;
    final url = origin.resolve('/api/mobile/v1').replace(queryParameters: params);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(url).timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 12));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Feed unavailable: HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) throw const FormatException('Invalid feed.');
      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}
