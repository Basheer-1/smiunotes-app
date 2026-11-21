import 'dart:convert';
import 'dart:io';

import '../models/member_notification.dart';

/// Staging-only REST client; access tokens are held only in memory.
class MobileNotificationApi {
  const MobileNotificationApi({required this.baseUrl});

  final String baseUrl;
  static const _path = '/api/mobile/v1/notifications';

  Uri _endpoint() {
    final url = Uri.tryParse(baseUrl);
    if (url == null || url.scheme != 'https' || url.host.isEmpty ||
        url.userInfo.isNotEmpty || url.hasQuery || url.hasFragment) {
      throw const FormatException('Approved HTTPS staging URL required.');
    }
    return url.resolve(_path);
  }

  String _bearer(String token) {
    if (token.length < 30 || token.length > 4096 ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(token)) {
      throw const FormatException('Student sign-in required.');
    }
    return 'Bearer $token';
  }

  Future<Map<String, dynamic>> _request(String token,
      {Map<String, String>? action}) async {
    final endpoint = _endpoint();
    final bearer = _bearer(token);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final HttpClientRequest request = action == null
          ? await client.getUrl(endpoint).timeout(const Duration(seconds: 12))
          : await client.postUrl(endpoint).timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, bearer);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (action != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(action));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.ok) {
        // Never include response bodies, URLs or tokens in error messages.
        throw const HttpException('Notification request unavailable.');
      }
      final raw = await utf8.decoder.bind(response).join().timeout(
        const Duration(seconds: 12));
      if (raw.length > 131072) {
        throw const FormatException('Notification response too large.');
      }
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid notification response.');
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }

  Future<MemberNotificationInbox> loadOwn(String token) async {
    final data = await _request(token);
    return MemberNotificationInbox.fromJson(data);
  }

  Future<void> markRead(String token, String id) async {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const FormatException('Invalid notification ID.');
    }
    final result = await _request(token, action: {'op': 'read', 'id': id});
    if (result['ok'] != true) {
      throw const FormatException('Read action not confirmed.');
    }
  }

  Future<int> clearOwn(String token) async {
    final result = await _request(token, action: {'op': 'clear'});
    final cleared = result['cleared'];
    if (result['ok'] != true || cleared is! int || cleared < 0) {
      throw const FormatException('Clear action not confirmed.');
    }
    return cleared;
  }
}
