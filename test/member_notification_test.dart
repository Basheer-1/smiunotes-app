import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/models/member_notification.dart';

void main() {
  final valid = <String, dynamic>{
    'id': '9fcdfc97-e3af-4c4e-a144-01e2ce25bd0e',
    'category': 'verification',
    'title': 'Account approved',
    'message': 'Your student verification was approved.',
    'created_at': '2026-11-21T12:00:00Z',
    'read_at': null,
  };

  test('unread notification decodes as unread', () {
    final item = MemberNotification.fromJson(valid);
    expect(item.isRead, isFalse);
    expect(item.title, 'Account approved');
    expect(item.createdAt.isUtc, isTrue);
  });

  test('valid read timestamp marks notification read', () {
    final item = MemberNotification.fromJson({
      ...valid,
      'read_at': '2026-11-21T12:05:00Z',
    });
    expect(item.isRead, isTrue);
  });

  test('reject malformed or missing required fields', () {
    for (final changes in <Map<String, dynamic>>[
      {'title': ''},
      {'message': 12},
      {'category': null},
      {'created_at': 'invalid'},
      {'read_at': 'invalid'},
      {'id': null},
    ]) {
      expect(
        () => MemberNotification.fromJson({...valid, ...changes}),
        throwsFormatException,
      );
    }
  });

  test('inbox parses valid count and rows', () {
    final inbox = MemberNotificationInbox.fromJson({
      'unread': 1,
      'items': [valid],
    });
    expect(inbox.unread, 1);
    expect(inbox.items, hasLength(1));
  });

  test('inbox rejects invalid counts and row structure', () {
    for (final count in [null, -1, 1.5, '1']) {
      expect(
        () => MemberNotificationInbox.fromJson({
          'unread': count,
          'items': [valid],
        }),
        throwsFormatException,
      );
    }
    expect(
      () => MemberNotificationInbox.fromJson({
        'unread': 1,
        'items': ['invalid'],
      }),
      throwsFormatException,
    );
  });
}
