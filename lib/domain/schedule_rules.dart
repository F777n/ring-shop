class TimeSlot {
  const TimeSlot({
    required this.id,
    required this.hallId,
    required this.startsAt,
    required this.endsAt,
    required this.title,
    this.deleted = false,
  });

  final int id;
  final int hallId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String title;
  final bool deleted;
}

/// Цена занятия с учётом действующей карты лояльности.
int chargedPrice(
  int priceRub, {
  required int discountPercent,
  required bool cardActive,
}) {
  if (priceRub < 0) return 0;
  if (!cardActive || discountPercent <= 0) return priceRub;
  final percent = discountPercent > 90 ? 90 : discountPercent;
  return (priceRub * (100 - percent) / 100).round();
}

bool intervalsOverlap(
  DateTime startA,
  DateTime endA,
  DateTime startB,
  DateTime endB,
) {
  return startA.isBefore(endB) && startB.isBefore(endA);
}

/// Тренировка, которая уже занимает тот же зал в пересекающееся время.
TimeSlot? conflictingSlot(Iterable<TimeSlot> existing, TimeSlot next) {
  for (final slot in existing) {
    if (slot.deleted || slot.id == next.id || slot.hallId != next.hallId) {
      continue;
    }
    if (intervalsOverlap(
        slot.startsAt, slot.endsAt, next.startsAt, next.endsAt)) {
      return slot;
    }
  }
  return null;
}
