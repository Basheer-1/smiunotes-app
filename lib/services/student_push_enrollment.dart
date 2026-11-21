import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'android_push_bridge.dart';
import 'push_registration_api.dart';

/// Explicit opt-in only, behind a separately approved build feature gate.
/// Device identifier is generated on-device; the Supabase backend stores
/// registration scoped to the currently authenticated account.
class StudentPushEnrollment {
  const StudentPushEnrollment({
    required this.api,
    this.bridge = const AndroidPushBridge(),
    this.storage = const FlutterSecureStorage(),
  });

  final PushRegistrationApi api;
  final AndroidPushBridge bridge;
  final FlutterSecureStorage storage;

  static const _idKey = 'smiunotes.android.device_id.v1';
  static const _enabledKey = 'smiunotes.android.push_optin.v1';

  Future<String> _deviceId() async {
    final existing = await storage.read(key: _idKey);
    if (existing != null &&
        RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(existing)) {
      return existing;
    }
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
    final id = String.fromCharCodes(bytes.map((b) => alphabet.codeUnitAt(b % alphabet.length)));
    await storage.write(key: _idKey, value: id);
    return id;
  }

  Future<bool> get isOptedIn async =>
      await storage.read(key: _enabledKey) == 'yes';

  Future<void> enable({required String currentAccessToken}) async {
    // The native permission prompt occurs only after this explicit action.
    // Caller must verify the Supabase student session before invoking.
    if (!api.enabled) throw StateError('Android push not available.');
    final deviceId = await _deviceId();
    final fcm = await bridge.requestToken(
      userOptedIn: true,
      verifiedSession: currentAccessToken.length >= 30,
    );
    try {
      await api.register(
        accessToken: currentAccessToken,
        deviceId: deviceId,
        fcmToken: fcm,
        userOptedIn: true,
        permissionGranted: true, // Android bridge only returns after OS grant.
      );
      await storage.write(key: _enabledKey, value: 'yes');
    } catch (_) {
      // No half-enrolled local state on a failed backend write.
      await storage.delete(key: _enabledKey);
      await bridge.deleteToken();
      rethrow;
    }
  }

  Future<void> disable({required String? currentAccessToken}) async {
    final id = await storage.read(key: _idKey);
    try {
      if (api.enabled && id != null && currentAccessToken != null) {
        await api.unregister(accessToken: currentAccessToken, deviceId: id);
      }
    } finally {
      // Local permission to receive is revoked even if server is offline.
      await storage.delete(key: _enabledKey);
      await bridge.deleteToken();
    }
  }
}
