import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_up/models/sleep_schedule.dart';

void main() {
  const s = SleepSchedule(startMinutes: 23 * 60, endMinutes: 7 * 60, days: {1, 2, 3, 4, 5});

  test('pencere gece yarısını geçer', () {
    expect(s.durationMinutes, 8 * 60);
    // 2026-11-02 Pazartesi
    expect(s.activeWindow(DateTime(2026, 11, 2, 23, 30)), isNotNull);
    expect(s.activeWindow(DateTime(2026, 11, 3, 6, 59)), isNotNull); // Pzt gecesi
    expect(s.activeWindow(DateTime(2026, 11, 3, 7, 0)), isNull);
    expect(s.activeWindow(DateTime(2026, 11, 2, 22, 59)), isNull);
  });

  test('programda olmayan gün kilitlenmez', () {
    // 2026-11-07 Cumartesi gecesi programda yok
    expect(s.activeWindow(DateTime(2026, 11, 7, 23, 30)), isNull);
    // Cuma gecesi Cumartesi sabahına uzanır
    expect(s.activeWindow(DateTime(2026, 11, 7, 3, 0)), isNotNull);
  });

  test('sonraki başlangıç hafta sonunu atlar', () {
    final next = s.nextStart(DateTime(2026, 11, 7, 12, 0)); // Cumartesi öğlen
    expect(next, DateTime(2026, 11, 9, 23, 0)); // Pazartesi 23:00
  });

  test('gece anahtarı sabah saatlerini önceki geceye sayar', () {
    expect(SleepSchedule.nightKey(DateTime(2026, 11, 3, 2, 0), 7 * 60), '2026-11-02');
    expect(SleepSchedule.nightKey(DateTime(2026, 11, 3, 8, 0), 7 * 60), '2026-11-03');
  });

  test('json gidiş-dönüş', () {
    final back = SleepSchedule.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
  });
}
