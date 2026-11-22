import 'package:flutter_test/flutter_test.dart';
import 'package:smiunotes_mobile/services/update_deadline.dart';

void main() {
  test('Updates status agrees with website priority and Karachi dates', () {
    final now = DateTime.utc(2026, 11, 22, 12);
    expect(universityUpdateStatus('2026-11-21', '2026-12-01',
      now: now), UniversityUpdateStatus.expired);
    expect(universityUpdateStatus('2026-11-22', '2026-12-01',
      now: now), UniversityUpdateStatus.upcoming);
    expect(universityUpdateStatus('2026-11-22', '2026-11-22',
      now: now), UniversityUpdateStatus.active);
    expect(universityUpdateStatus(null, null, now: now),
      UniversityUpdateStatus.active);
  });

  test('Karachi deadline stays open through the final day', () {
    expect(isUpdateApplicationExpired('2026-11-22',
      now: DateTime.utc(2026, 11, 22, 18, 59)), isFalse);
    expect(isUpdateApplicationExpired('2026-11-22',
      now: DateTime.utc(2026, 11, 22, 19, 0)), isTrue);
  });

  test('Future and absent deadlines do not disable applications', () {
    expect(isUpdateApplicationExpired('2026-11-23',
      now: DateTime.utc(2026, 11, 22)), isFalse);
    expect(isUpdateApplicationExpired(null,
      now: DateTime.utc(2026, 11, 22)), isFalse);
  });

  test('An expired deadline always disables applications', () {
    expect(isUpdateApplicationExpired('2026-11-21',
      now: DateTime.utc(2026, 11, 22)), isTrue);
  });
}
