import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/services/mobile_auth_api.dart';

void main() {
  test('accepts a Supabase session with a 12-character refresh token', () {
    final session = MobileSession.fromJson({
      'session': {
        'access_token': 'x' * 40,
        'refresh_token': '123456789012',
      },
      'verification_status': 'verified',
    });
    expect(session.refreshToken, '123456789012');
    expect(session.verificationStatus, 'verified');
  });

  test('rejects malformed refresh tokens', () {
    expect(
      () => MobileSession.fromJson({
        'session': {'access_token': 'x' * 40, 'refresh_token': 'short'}
      }),
      throwsFormatException,
    );
  });
}
