import 'dart:convert';
import 'dart:io';

import '../models/student_profile.dart';

/// Use only after a validated mobile sign-in has obtained a short-lived access
/// token. The access token MUST come from OS-backed secure session storage,
/// never from a hardcoded string or --dart-define.
class StudentProfileApi {
  const StudentProfileApi({required this.baseUrl});
  final String baseUrl;

  Future<StudentProfile> fetchOwnProfile(String accessToken) async {
    if (accessToken.length < 30 || accessToken.length > 4096 ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(accessToken)) {
      throw const FormatException('Sign-in required.');
    }
    final origin = Uri.tryParse(baseUrl);
    if (origin == null || origin.scheme != 'https' ||
        origin.host.isEmpty || origin.userInfo.isNotEmpty ||
        origin.hasQuery || origin.hasFragment) {
      throw const FormatException('Configure a trusted HTTPS staging URL.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final url = origin.resolve('/api/mobile/v1/me');
      final request = await client.getUrl(url).timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw const HttpException('Unable to load account.');
      }
      final raw = await utf8.decoder.bind(response).join()
          .timeout(const Duration(seconds: 12));
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid account response.');
      }
      return StudentProfile.fromJson(value);
    } finally {
      client.close(force: true);
    }
  }
}
