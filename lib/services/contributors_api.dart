import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

/// Public contributor catalogue; no student authentication or private IDs.
class ContributorsApi {
  const ContributorsApi({this.baseUrl = const String.fromEnvironment(
    'SMIUNOTES_API_BASE', defaultValue: '',
  )});
  final String baseUrl;

  Future<Map<String, dynamic>> fetch({
    String query = '', String department = '', String sort = 'notes',
    int page = 1, int departmentsPage = 1,
  }) async {
    final origin = Uri.tryParse(baseUrl);
    if (origin == null || origin.scheme != 'https' || origin.host.isEmpty ||
        origin.userInfo.isNotEmpty || origin.hasQuery || origin.hasFragment ||
        page < 1 || page > 9999 || departmentsPage < 1 ||
        departmentsPage > 9999 || query.length > 100 ||
        (sort != 'name' && sort != 'notes')) {
      throw const FormatException('Invalid contributors request.');
    }
    final endpoint = origin.resolve('/api/mobile/v1/contributors').replace(
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (department.isNotEmpty) 'department': department,
        'sort': sort,
        'page': page.toString(),
        'departmentsPage': departmentsPage.toString(),
      },
    );
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(endpoint)
          .timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close()
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != HttpStatus.ok ||
          response.headers.contentType?.mimeType != 'application/json') {
        throw const HttpException('Contributors temporarily unavailable.');
      }
      final bytes = BytesBuilder(copy: false);
      var length = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 12))) {
        length += chunk.length;
        if (length > 750000) {
          throw const FormatException('Contributors response too large.');
        }
        bytes.add(chunk);
      }
      final value = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid contributors response.');
      }
      return value;
    } finally {
      client.close(force: true);
    }
  }
}
