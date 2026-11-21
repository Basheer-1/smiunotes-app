import 'package:flutter/services.dart';

/// Android FCM transport only; Supabase owns authentication and device grants.
/// This bridge never runs automatically. User opt-in + a verified current
/// session are required before the app may request the native token.
class AndroidPushBridge {
  const AndroidPushBridge();

  static const MethodChannel _channel = MethodChannel('smiunotes/push');

  Future<String> requestToken({
    required bool userOptedIn,
    required bool verifiedSession,
  }) async {
    if (!userOptedIn || !verifiedSession) {
      throw StateError('Verified sign-in and notification consent required.');
    }
    final token = await _channel.invokeMethod<String>(
      'requestToken', {'consent': true},
    );
    if (token == null || token.length < 30 || token.length > 4096 ||
        !RegExp(r'^[A-Za-z0-9:_-]+$').hasMatch(token)) {
      throw const FormatException('Native push token unavailable.');
    }
    return token;
  }

  /// Only call after server-side device unregister succeeds, or after an
  /// explicit local privacy reset when server deletion cannot be reached.
  Future<void> deleteToken() => _channel.invokeMethod<void>('disablePush');
}
