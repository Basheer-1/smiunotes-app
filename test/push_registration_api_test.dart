import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/services/push_registration_api.dart';

void main() {
  const api = PushRegistrationApi(baseUrl: 'https://isolated-preview.example.com');
  const session = 'abcdefghijklmnopqrstuvwxyzABCDEF123456';
  const device = 'device_token_0123456789';
  const fcmToken = 'fcm_test_token_abcdefghijklmnopqrstuvwxyz123456';

  test('push registration is disabled by default with explicit consent', () async {
    await expectLater(
      api.register(
        accessToken: session,
        deviceId: device,
        fcmToken: fcmToken,
        userOptedIn: true,
        permissionGranted: true,
      ),
      throwsStateError,
    );
  });

  test('opt-in and OS grant must both be present', () async {
    const gated = PushRegistrationApi(
      baseUrl: 'https://isolated-preview.example.com', enabled: true,
    );
    await expectLater(
      gated.register(
        accessToken: session,
        deviceId: device,
        fcmToken: fcmToken,
        userOptedIn: false,
        permissionGranted: true,
      ),
      throwsStateError,
    );
    await expectLater(
      gated.register(
        accessToken: session,
        deviceId: device,
        fcmToken: fcmToken,
        userOptedIn: true,
        permissionGranted: false,
      ),
      throwsStateError,
    );
  });

  test('invalid device and FCM identifiers are rejected before network', () async {
    const gated = PushRegistrationApi(
      baseUrl: 'https://isolated-preview.example.com', enabled: true,
    );
    await expectLater(
      gated.register(
        accessToken: session,
        deviceId: 'short',
        fcmToken: fcmToken,
        userOptedIn: true,
        permissionGranted: true,
      ),
      throwsFormatException,
    );
    await expectLater(
      gated.register(
        accessToken: session,
        deviceId: device,
        fcmToken: 'bad',
        userOptedIn: true,
        permissionGranted: true,
      ),
      throwsFormatException,
    );
    await expectLater(
      gated.unregister(accessToken: session, deviceId: 'x'),
      throwsFormatException,
    );
  });

  test('invalid or missing signed-in access token is rejected', () async {
    const gated = PushRegistrationApi(
      baseUrl: 'https://isolated-preview.example.com', enabled: true,
    );
    await expectLater(
      gated.unregister(accessToken: 'invalid', deviceId: device),
      throwsFormatException,
    );
  });

  test('insecure and cross-host API origins are rejected', () async {
    const gated = PushRegistrationApi(
      baseUrl: 'http://example.com', enabled: true,
    );
    await expectLater(
      gated.unregister(accessToken: session, deviceId: device),
      throwsFormatException,
    );
  });
}
