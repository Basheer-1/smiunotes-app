import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/services/android_push_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = AndroidPushBridge();
  const channel = MethodChannel('smiunotes/push');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var calls = <MethodCall>[];

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'requestToken') {
        return 'fake_test_token_abcdefghijklmnopqrstuvwxyz123456789';
      }
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('guest and opt-out never invoke Android FCM token enrollment', () async {
    await expectLater(
      bridge.requestToken(userOptedIn: true, verifiedSession: false),
      throwsStateError,
    );
    await expectLater(
      bridge.requestToken(userOptedIn: false, verifiedSession: true),
      throwsStateError,
    );
    expect(calls, isEmpty);
  });

  test('verified opt-in invokes native token request with consent', () async {
    final token = await bridge.requestToken(
      userOptedIn: true, verifiedSession: true,
    );
    expect(token, startsWith('fake_test_token_'));
    expect(calls, hasLength(1));
    expect(calls.single.method, 'requestToken');
    expect(calls.single.arguments, {'consent': true});
  });

  test('explicit local disable invokes native deletion', () async {
    await bridge.deleteToken();
    expect(calls.single.method, 'disablePush');
  });

  test('malformed native token is rejected', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => 'short');
    await expectLater(
      bridge.requestToken(userOptedIn: true, verifiedSession: true),
      throwsFormatException,
    );
  });
}
