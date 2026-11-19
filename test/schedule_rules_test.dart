import 'package:flutter_test/flutter_test.dart';
import 'package:ring_shop/domain/schedule_rules.dart';
import 'package:ring_shop/repositories/schedule_repository.dart';
import 'package:ring_shop/core/api_exceptions.dart';
import 'package:ring_shop/models/schedule.dart';

void main() {
  test('скидка карты уменьшает цену', () {
    expect(chargedPrice(3000, discountPercent: 10, cardActive: true), 2700);
    expect(chargedPrice(3000, discountPercent: 10, cardActive: false), 3000);
    expect(chargedPrice(3000, discountPercent: 0, cardActive: true), 3000);
  });

  test('пересечение интервалов', () {
    final start = DateTime.utc(2026, 11, 20, 15);
    final end = DateTime.utc(2026, 11, 20, 16, 30);
    expect(
      intervalsOverlap(start, end, DateTime.utc(2026, 11, 20, 16), DateTime.utc(2026, 11, 20, 17)),
      isTrue,
    );
    expect(
      intervalsOverlap(start, end, DateTime.utc(2026, 11, 20, 17), DateTime.utc(2026, 11, 20, 18)),
      isFalse,
    );
  });

  test('тот же зал в то же время отклоняется', () async {
    final repository = InMemoryTrainingRepository(latency: Duration.zero);
    expect(
      () => repository.create(
        Training(
          id: 0,
          title: 'Второе занятие',
          hallId: 1,
          coachId: 2,
          disciplineId: 1,
          startsAt: DateTime.utc(2026, 11, 20, 15, 30),
          endsAt: DateTime.utc(2026, 11, 20, 16),
          priceRub: 2000,
        ),
      ),
      throwsA(isA<ConflictException>()),
    );
  });
}
