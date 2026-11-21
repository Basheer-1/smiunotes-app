import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'mobile_auth_api.dart';

/// Never use SharedPreferences for access or refresh tokens.
/// One structured record avoids independently written token/key mismatches.
abstract class SessionVault {
  Future<void> save(MobileSession session);
  Future<MobileSession?> read();
  Future<void> clear();
}

class SecureSessionStore implements SessionVault {
  const SecureSessionStore({
    this.storage = const FlutterSecureStorage(),
  });

  static const _key = 'smiunotes.student_session.v1';
  final FlutterSecureStorage storage;

  @override
  Future<void> save(MobileSession session) async {
    await storage.write(
      key: _key,
      value: jsonEncode({
        'version': 1,
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
        'verification_status': session.verificationStatus,
      }),
    );
  }

  @override
  Future<MobileSession?> read() async {
    final encoded = await storage.read(key: _key);
    if (encoded == null) return null;
    try {
      final payload = jsonDecode(encoded);
      if (payload is! Map<String, dynamic> || payload['version'] != 1) {
        throw const FormatException('Invalid session version');
      }
      return MobileSession.fromJson({
        'session': {
          'access_token': payload['access_token'],
          'refresh_token': payload['refresh_token'],
        },
        'verification_status': payload['verification_status'],
      });
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> clear() => storage.delete(key: _key);
}

/// Only an OS-backed storage engine may receive a live credential.
/// No plaintext disk or diagnostic log copies are made.
