import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// The native Support endpoint is not deployed on this API origin.
class NativeSupportNotAvailable implements Exception {
  const NativeSupportNotAvailable();
}

/// Native student form transport. Only configured HTTPS API origin; no secrets.
class NativeStudentFormsApi {
  const NativeStudentFormsApi({required this.baseUrl, required this.tokenProvider});
  final String baseUrl;
  final String Function()? tokenProvider;

  Uri _url(String path) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException('Trusted HTTPS origin required.');
    }
    return uri.resolve('/api/mobile/v1/$path');
  }

  Future<Map<String, dynamic>> _send(String path, {
    Map<String, dynamic>? fields,
    Uint8List? image,
    String imageField = 'card',
    bool get = false,
    bool authorized = true,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = get
        ? await client.getUrl(_url(path)).timeout(const Duration(seconds: 12))
        : await client.postUrl(_url(path)).timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (authorized) {
        final token = tokenProvider?.call();
        if (token == null || token.length < 30 ||
            !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(token)) {
          throw StateError('Student sign-in required.');
        }
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (!get && image == null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(fields ?? {}));
      } else if (image != null) {
        if (image.length < 2000 || image.length > 2500000) {
          throw const FormatException('Choose an image between 2 KB and 2.5 MB.');
        }
        final boundary = 'smiunotes-native-form-boundary';
        request.headers.set(HttpHeaders.contentTypeHeader,
          'multipart/form-data; boundary=$boundary');
        for (final entry in (fields ?? {}).entries) {
          if (!RegExp(r'^[a-z_]+$').hasMatch(entry.key)) {
            throw const FormatException('Invalid form field.');
          }
          request.write('--$boundary\r\n'
            'Content-Disposition: form-data; name="${entry.key}"\r\n\r\n'
            '${entry.value}\r\n');
        }
        request.write('--$boundary\r\n'
          'Content-Disposition: form-data; name="$imageField"; filename="image.jpg"\r\n'
          'Content-Type: application/octet-stream\r\n\r\n');
        request.add(image);
        request.write('\r\n--$boundary--\r\n');
      }
      final response = await request.close().timeout(const Duration(seconds: 35));
      if (path == 'support' && response.statusCode == HttpStatus.notFound) {
        throw const NativeSupportNotAvailable();
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        if (bytes.length + chunk.length > 32768) {
          throw const FormatException('Response too large.');
        }
        bytes.addAll(chunk);
      }
      final parsed = jsonDecode(utf8.decode(bytes));
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Invalid server response.');
      }
      if (response.statusCode != 200) {
        // Never show raw backend errors or tokens to the user.
        throw StateError('Request failed (HTTP ${response.statusCode}).');
      }
      return parsed;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> sendContact({
    required String name,
    required String email,
    required String topic,
    required String subject,
    required String message,
    required String proof,
    required int elapsedMs,
    bool signedIn = false,
  }) async {
    final result = await _send('contact', authorized: signedIn, fields: {
      'name': name, 'email': email, 'topic': topic,
      'subject': subject, 'message': message,
      'token': proof, 'elapsedMs': elapsedMs,
    });
    if (result['ok'] != true) throw StateError('Message was not confirmed.');
  }

  Future<void> submitStudentCard(Uint8List bytes) async {
    final result = await _send('verification', image: bytes);
    if (result['ok'] != true || result['status'] != 'submitted') {
      throw StateError('Student Card not confirmed.');
    }
  }

  Future<Map<String, dynamic>> supportOptions({bool signedIn = true}) =>
      _send('support', get: true, authorized: signedIn);

  Future<void> submitSupport({
    required Uint8List receipt,
    required String methodId,
    required String amount,
    required String phone,
    required String note,
    required String name,
    required bool publicName,
    required bool publicAmount,
    required int startedAt,
    bool signedIn = true,
  }) async {
    final result = await _send('support', image: receipt, imageField: 'proof',
      authorized: signedIn,
      fields: {
        'method_id': methodId, 'amount': amount, 'phone': phone,
        'name': name, 'note': note, 'consent': 'yes',
        'started_at': startedAt.toString(),
        'public_name': publicName ? 'yes' : 'no',
        'public_amount': publicAmount ? 'yes' : 'no',
      });
    if (result['ok'] != true || result['status'] != 'pending_review') {
      throw StateError('Receipt claim was not confirmed.');
    }
  }

  static const MethodChannel _picker = MethodChannel('smiunotes/media_picker');

  static Future<Uint8List?> chooseImage() async {
    final bytes = await _picker.invokeMethod<Uint8List>('chooseImage');
    if (bytes == null) return null;
    if (bytes.length < 2000 || bytes.length > 2500000) {
      throw const FormatException('Image must be 2 KB–2.5 MB.');
    }
    return bytes;
  }
}
