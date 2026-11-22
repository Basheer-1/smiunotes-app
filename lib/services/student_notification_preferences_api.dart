import 'dart:convert';
import 'dart:io';

/// Owner-only notification settings; never caches access tokens on device.
class StudentNotificationPreferencesApi {
  const StudentNotificationPreferencesApi({required this.baseUrl});
  final String baseUrl;

  Uri get _endpoint {
    final origin = Uri.tryParse(baseUrl);
    if (origin == null || origin.scheme != 'https' ||
        origin.host.isEmpty || origin.userInfo.isNotEmpty ||
        origin.hasQuery || origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      throw const FormatException('Trusted HTTPS API origin required.');
    }
    return origin.resolve('/api/mobile/v1/preferences');
  }

  Future<Map<String, dynamic>> read(String token) => _call(token);

  Future<void> save(String token, bool enabled) async {
    final response = await _call(token, update: enabled);
    if (response['ok'] != true || response['notify_updates'] != enabled ||
        response['notify_notes'] != false) {
      throw const FormatException('Preference update not confirmed.');
    }
  }

  Future<Map<String, dynamic>> _call(String token, {bool? update}) async {
    if (!RegExp(r'^[A-Za-z0-9._-]{30,4096}$').hasMatch(token)) {
      throw const FormatException('Verified sign-in required.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = update == null
          ? await client.getUrl(_endpoint).timeout(const Duration(seconds: 12))
          : await client.postUrl(_endpoint).timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (update != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'notify_updates': update}));
      }
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != HttpStatus.ok ||
          response.headers.contentType?.mimeType != 'application/json') {
        throw const HttpException('Notification preferences unavailable.');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        if (bytes.length + chunk.length > 8192) {
          throw const FormatException('Invalid preferences response.');
        }
        bytes.addAll(chunk);
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid preferences response.');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}
