import 'dart:convert';
import 'dart:io';

/// Future FCM integration contract. No Firebase SDK is initialized here.
/// Feature stays disabled until server-side ownership, delivery, and revoke
/// acceptance is complete. Never call with a cached bearer after sign-out.
class PushRegistrationApi {
  const PushRegistrationApi({
    required this.baseUrl,
    this.enabled = false,
  });

  final String baseUrl;
  final bool enabled;

  static const String path = '/api/mobile/v1/push';

  Uri _endpoint() {
    final base = Uri.tryParse(baseUrl);
    if (base == null || base.scheme != 'https' || base.host.isEmpty ||
        base.userInfo.isNotEmpty || base.hasQuery || base.hasFragment ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw const FormatException('Approved HTTPS mobile API origin required.');
    }
    return base.resolve(path);
  }

  static void _validateSession(String accessToken) {
    if (accessToken.length < 30 || accessToken.length > 4096 ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(accessToken)) {
      throw const FormatException('Verified student session required.');
    }
  }

  static void _validateDeviceId(String deviceId) {
    if (!RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(deviceId)) {
      throw const FormatException('Invalid device identifier.');
    }
  }

  static void _validateFcmToken(String fcmToken) {
    if (fcmToken.length < 30 || fcmToken.length > 4096 ||
        !RegExp(r'^[A-Za-z0-9:_-]+$').hasMatch(fcmToken)) {
      throw const FormatException('Invalid push registration token.');
    }
  }

  Future<void> _post(
    String accessToken,
    Map<String, String> payload,
  ) async {
    if (!enabled) {
      throw StateError('Native push is not approved for this build.');
    }
    _validateSession(accessToken);
    final url = _endpoint();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(url).timeout(
        const Duration(seconds: 12),
      );
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(
        const Duration(seconds: 18),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw const HttpException('Push registration unavailable.');
      }
      var total = 0;
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 8))) {
        total += chunk.length;
        if (total > 4096) {
          throw const FormatException('Push response too large.');
        }
        bytes.addAll(chunk);
      }
      final result = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (result is! Map<String, dynamic> || result['ok'] != true) {
        throw const FormatException('Push action was not confirmed.');
      }
    } finally {
      client.close(force: true);
    }
  }

  /// Must only be called after explicit user opt-in and OS notification grant.
  /// Never subscribe to note-publication broadcasts.
  Future<void> register({
    required String accessToken,
    required String deviceId,
    required String fcmToken,
    required bool userOptedIn,
    required bool permissionGranted,
  }) async {
    if (!userOptedIn || !permissionGranted) {
      throw StateError('Notification consent and permission are required.');
    }
    _validateDeviceId(deviceId);
    _validateFcmToken(fcmToken);
    await _post(accessToken, {
      'op': 'register',
      'platform': 'android',
      'deviceId': deviceId,
      'token': fcmToken,
    });
  }

  /// Called for logout, account revocation and explicit opt-out.
  Future<void> unregister({
    required String accessToken,
    required String deviceId,
  }) async {
    _validateDeviceId(deviceId);
    await _post(accessToken, {
      'op': 'unregister',
      'platform': 'android',
      'deviceId': deviceId,
    });
  }
}
