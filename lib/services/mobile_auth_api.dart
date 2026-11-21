import 'dart:convert';
import 'dart:io';

/// Ephemeral tokens are deliberately not logged or persisted by this class.
/// Production login requires a trusted Turnstile challenge and secure
/// OS-backed session storage before UI activation.
class MobileSession {
  const MobileSession({
    required this.accessToken,
    required this.refreshToken,
    required this.verificationStatus,
  });

  final String accessToken;
  final String refreshToken;
  final String verificationStatus;

  factory MobileSession.fromJson(Map<String, dynamic> json) {
    final session = json['session'];
    if (session is! Map<String, dynamic>) {
      throw const FormatException('Invalid sign-in response.');
    }
    final access = session['access_token'];
    final refresh = session['refresh_token'];
    if (access is! String || refresh is! String ||
        access.length < 30 || refresh.length < 20) {
      throw const FormatException('Invalid sign-in response.');
    }
    return MobileSession(
      accessToken: access,
      refreshToken: refresh,
      verificationStatus: json['verification_status'] is String
          ? json['verification_status'] as String : 'unknown',
    );
  }
}

class MobileAuthApi {
  const MobileAuthApi({required this.baseUrl});
  final String baseUrl;

  Uri _base() {
    final origin = Uri.tryParse(baseUrl);
    if (origin == null || origin.scheme != 'https' ||
        origin.host.isEmpty || origin.userInfo.isNotEmpty ||
        origin.hasQuery || origin.hasFragment) {
      throw const FormatException('Configure a trusted HTTPS staging URL.');
    }
    return origin;
  }

  Future<bool> isEnabled() async {
    final url = _base().resolve('/api/mobile/v1/auth');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(url).timeout(
        const Duration(seconds: 12));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 12));
      if (response.statusCode != HttpStatus.ok) return false;
      final body = await utf8.decoder.bind(response).join().timeout(
        const Duration(seconds: 12));
      final data = jsonDecode(body);
      return data is Map<String, dynamic> && data['enabled'] == true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _post(Map<String, String> body) async {
    final url = _base().resolve('/api/mobile/v1/auth');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(url).timeout(
        const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 22));
      final raw = await utf8.decoder.bind(response).join().timeout(
        const Duration(seconds: 12));
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid authentication response.');
      }
      if (response.statusCode != HttpStatus.ok) {
        // Never include raw server responses or credentials in error logs.
        final message = decoded['error'];
        throw HttpException(message is String && message.length < 160
            ? message : 'Sign-in unavailable.');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<MobileSession> passwordLogin({
    required String studentId,
    required String password,
    required String turnstileToken,
  }) async {
    if (studentId.isEmpty || password.isEmpty || turnstileToken.isEmpty) {
      throw const FormatException('Complete all sign-in fields.');
    }
    final data = await _post({
      'op': 'password', 'studentId': studentId,
      'password': password, 'turnstileToken': turnstileToken,
    });
    return MobileSession.fromJson(data);
  }

  Future<String> startOtp({
    required String studentId,
    String email = '',
    required String turnstileToken,
  }) async {
    if (studentId.isEmpty || turnstileToken.isEmpty) {
      throw const FormatException('Complete the verification fields.');
    }
    final data = await _post({
      'op': 'send', 'studentId': studentId,
      'email': email, 'turnstileToken': turnstileToken,
    });
    final challenge = data['challenge'];
    if (challenge is! String ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(challenge)) {
      throw const FormatException('Invalid OTP challenge.');
    }
    return challenge;
  }

  Future<MobileSession> verifyOtp({
    required String challenge,
    required String code,
    required String newPassword,
  }) async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(challenge) ||
        !RegExp(r'^\d{6}$').hasMatch(code) ||
        newPassword.length < 12 || newPassword.length > 128) {
      throw const FormatException('Invalid verification input.');
    }
    final data = await _post({
      'op': 'verify', 'challenge': challenge,
      'code': code, 'newPassword': newPassword,
    });
    return MobileSession.fromJson(data);
  }
}
