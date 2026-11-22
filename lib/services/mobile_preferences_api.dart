import 'dart:convert';
import 'dart:io';

/// Own-account university update preference using the existing mobile API.
/// Essential alerts remain enabled and new-notes alerts remain disabled.
class MobilePreferencesApi {
  const MobilePreferencesApi({required this.baseUrl});
  final String baseUrl;

  Uri _endpoint() {
    final url = Uri.tryParse(baseUrl);
    if (url == null || url.scheme != 'https' || url.host.isEmpty ||
        url.userInfo.isNotEmpty || url.hasQuery || url.hasFragment ||
        (url.path.isNotEmpty && url.path != '/')) {
      throw const FormatException('Trusted HTTPS endpoint required.');
    }
    return url.resolve('/api/mobile/v1/preferences');
  }

  Future<Map<String, dynamic>> _request(String token, {bool? updates}) async {
    if (token.length < 30 || token.length > 4096 ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(token)) {
      throw const FormatException('Student sign-in required.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = updates == null
          ? await client.getUrl(_endpoint()).timeout(const Duration(seconds: 12))
          : await client.postUrl(_endpoint()).timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (updates != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'notify_updates': updates}));
      }
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw const HttpException('Notification preferences unavailable.');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 12))) {
        if (bytes.length + chunk.length > 8192) {
          throw const FormatException('Preferences response too large.');
        }
        bytes.addAll(chunk);
      }
      final payload = jsonDecode(utf8.decode(bytes));
      if (payload is! Map<String, dynamic> ||
          payload['notify_updates'] is! bool ||
          payload['essential_alerts'] != true ||
          payload['notify_notes'] != false ||
          (updates != null &&
              (payload['ok'] != true || payload['notify_updates'] != updates))) {
        throw const FormatException('Invalid preferences confirmation.');
      }
      return payload;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> load(String token) async {
    final result = await _request(token);
    return result['notify_updates'] == true;
  }

  Future<bool> save(String token, bool enabled) async {
    final result = await _request(token, updates: enabled);
    return result['notify_updates'] == true;
  }
}
