import 'dart:convert';
import 'dart:io';

import 'mobile_auth_api.dart';

/// Session refresh/revoke requests contain credentials, so neither URLs nor
/// token values should ever be logged or stored outside the encrypted vault.
class StudentSessionApi {
  const StudentSessionApi({required this.baseUrl});
  final String baseUrl;

  Uri _endpoint() {
    final origin = Uri.tryParse(baseUrl);
    if (origin == null || origin.scheme != 'https' || origin.host.isEmpty ||
        origin.userInfo.isNotEmpty || origin.hasQuery || origin.hasFragment) {
      throw const FormatException('Configure a trusted HTTPS staging URL.');
    }
    return origin.resolve('/api/mobile/v1/session');
  }

  Future<Map<String, dynamic>> _send(
    Map<String, String> body, {String? bearer}
  ) async {
    final url = _endpoint();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(url).timeout(
        const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (bearer != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
      }
      request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.ok) {
        throw const HttpException('Student session unavailable.');
      }
      final raw = await utf8.decoder.bind(response).join().timeout(
        const Duration(seconds: 12));
      final result = jsonDecode(raw);
      if (result is! Map<String, dynamic>) {
        throw const FormatException('Invalid session response.');
      }
      return result;
    } finally {
      client.close(force: true);
    }
  }

  Future<MobileSession> renew(String refreshToken) async {
    if (!RegExp(r'^[A-Za-z0-9._-]{20,4096}$').hasMatch(refreshToken)) {
      throw const FormatException('Invalid refresh token.');
    }
    final data = await _send({
      'op': 'refresh',
      'refreshToken': refreshToken,
    });
    return MobileSession.fromJson(data);
  }

  Future<void> revokeAll(String accessToken) async {
    if (!RegExp(r'^[A-Za-z0-9._-]{30,4096}$').hasMatch(accessToken)) {
      throw const FormatException('Invalid access token.');
    }
    final data = await _send({'op': 'logout_all'}, bearer: accessToken);
    if (data['signed_out'] != true) {
      throw const FormatException('All-device revoke not confirmed.');
    }
  }
  Future<void> revoke(String accessToken) async {
    if (!RegExp(r'^[A-Za-z0-9._-]{30,4096}$').hasMatch(accessToken)) {
      throw const FormatException('Invalid access token.');
    }
    final data = await _send({'op': 'logout'}, bearer: accessToken);
    if (data['signed_out'] != true) {
      throw const FormatException('Session revoke not confirmed.');
    }
  }
}
