import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/services/mobile_auth_api.dart';

void main() {
  test('Rejects missing or short session tokens', () {
    expect(() => MobileSession.fromJson({}), throwsFormatException);
    expect(
      () => MobileSession.fromJson({
        'session': {'access_token': 'short', 'refresh_token': 'short'},
      }),
      throwsFormatException,
    );
  });

  test('Parses only valid authentication token envelope', () {
    final session = MobileSession.fromJson({
      'session': {
        'access_token': 'a' * 64,
        'refresh_token': 'b' * 48,
      },
      'verification_status': 'verified',
    });
    expect(session.verificationStatus, 'verified');
    expect(session.accessToken.length, 64);
  });

  test('Rejects malformed OTP input before any network request', () async {
    const api = MobileAuthApi(baseUrl: 'https://staging.example.com');
    await expectLater(
      api.verifyOtp(
        challenge: 'not-a-uuid', code: '1234',
        newPassword: 'a-very-secure-new-password',
      ),
      throwsFormatException,
    );
  });
}
