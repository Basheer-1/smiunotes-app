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

  Future<Map<String, dynamic>> fetch(
    String kind, {
    int page = 1,
    String search = '',
    String stream = '',
    String department = '',
    String semester = '',
    String subject = '',
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
