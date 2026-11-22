import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Native profile settings use the same HTTPS mobile API and the caller's
/// freshly retrieved bearer token. Never persist passwords, photos or tokens.
class NativeProfileSettingsApi {
  const NativeProfileSettingsApi({
    required this.baseUrl,
    required this.tokenProvider,
  });
  final String baseUrl;
  final String Function() tokenProvider;

  Uri _uri(String endpoint) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException('Trusted HTTPS origin required.');
    }
    return uri.resolve('/api/mobile/v1/$endpoint');
  }

  Future<Map<String, dynamic>> _request(
    String endpoint, {Map<String, dynamic>? body, Uint8List? photo,
  }) async {
    final token = tokenProvider();
    if (token.length < 30 || token.length > 4096 ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(token)) {
      throw StateError('Student sign-in required.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = body == null && photo == null && !endpoint.contains('?')
        ? await client.getUrl(_uri(endpoint)).timeout(const Duration(seconds: 12))
        : await client.postUrl(_uri(endpoint)).timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (photo != null) {
        if (photo.length < 2000 || photo.length > 2 * 1024 * 1024) {
          throw const FormatException('Choose a photo under 2 MB.');
        }
        const boundary = 'smiunotes-profile-image';
        request.headers.set(HttpHeaders.contentTypeHeader,
          'multipart/form-data; boundary=$boundary');
        request.write('--$boundary\r\n'
          'Content-Disposition: form-data; name="photo"; filename="profile.jpg"\r\n'
          'Content-Type: application/octet-stream\r\n\r\n');
        request.add(photo);
        request.write('\r\n--$boundary--\r\n');
      } else if (body != null || endpoint.contains('?')) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body ?? <String, dynamic>{}));
      }
      final response = await request.close().timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw HttpException('Profile action unavailable (HTTP ${response.statusCode}).');
      }
      final buffer = <int>[];
      await for (final part in response.timeout(const Duration(seconds: 12))) {
        if (buffer.length + part.length > 32768) {
          throw const FormatException('Profile response too large.');
        }
        buffer.addAll(part);
      }
      final result = jsonDecode(utf8.decode(buffer));
      if (result is! Map<String, dynamic>) {
        throw const FormatException('Invalid profile response.');
      }
      return result;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> loadSettings() => _request('settings');

  Future<void> renameDevice(String sessionId, String nickname) async {
    final result = await _request('settings', body: {
      'op': 'rename_device', 'session_id': sessionId, 'nickname': nickname,
    });
    if (result['ok'] != true) throw StateError('Could not rename device.');
  }

  Future<void> removeDevice(String sessionId) async {
    final result = await _request('settings', body: {
      'op': 'remove_device', 'session_id': sessionId,
    });
    if (result['ok'] != true) throw StateError('Could not revoke device.');
  }

  Future<void> changePassword(String current, String next, String confirm) async {
    final result = await _request('settings', body: {
      'op': 'change_password',
      'current_password': current,
      'new_password': next,
      'confirm_password': confirm,
    });
    if (result['ok'] != true) throw StateError('Password was not updated.');
  }

  Future<void> savePhoto(Uint8List bytes) async {
    final result = await _request('profile-photo?action=upload', photo: bytes);
    if (result['ok'] != true) throw StateError('Photo was not updated.');
  }

  Future<void> removePhoto() async {
    final result = await _request('profile-photo?action=remove', body: {});
    if (result['ok'] != true) throw StateError('Photo was not removed.');
  }
}
