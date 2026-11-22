import 'dart:io';
import 'dart:typed_data';

/// Own-account avatar image only. The bearer is taken from the current verified
/// session at request time, never embedded in a public URL.
class NativeAvatarApi {
  const NativeAvatarApi({required this.baseUrl});
  final String baseUrl;

  Future<Uint8List?> loadOwn(String accessToken) async {
    if (!RegExp(r'^[A-Za-z0-9._-]{30,4096}$').hasMatch(accessToken)) {
      throw const FormatException('Verified sign-in required.');
    }
    final origin = Uri.tryParse(baseUrl);
    if (origin == null || origin.scheme != 'https' || origin.host.isEmpty ||
        origin.userInfo.isNotEmpty || origin.hasQuery || origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      throw const FormatException('Trusted HTTPS API origin required.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(
        origin.resolve('/api/mobile/v1/avatar'),
      ).timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      final response = await request.close().timeout(const Duration(seconds: 12));
      if (response.statusCode == HttpStatus.notFound) return null;
      if (response.statusCode != HttpStatus.ok ||
          response.headers.contentType?.mimeType != 'image/webp') {
        throw const HttpException('Avatar not available.');
      }
      final data = BytesBuilder(copy: false);
      var total = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        total += chunk.length;
        if (total > 500000) throw const FormatException('Avatar too large.');
        data.add(chunk);
      }
      return data.takeBytes();
    } finally {
      client.close(force: true);
    }
  }
}
