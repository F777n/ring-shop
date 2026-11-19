import '../models/schedule.dart';

List<Coach> buildSeedCoaches() {
  return const [
    Coach(
      id: 1,
      name: 'Игорь Волков',
      rank: 'МС',
      phone: '+79002000001',
      disciplineIds: [1, 11],
    ),
    Coach(
      id: 2,
      name: 'Анна Ким',
      rank: 'КМС',
      phone: '+79002000002',
      disciplineIds: [1, 2],
    ),
    Coach(
      id: 3,
      name: 'Сергей Дроздов',
      rank: 'МСМК',
      phone: '+79002000003',
      disciplineIds: [2, 9],
    ),
  ];
}

List<Hall> buildSeedHalls() {
  return const [
    Hall(
      id: 1,
      name: 'Ринг А',
      address: 'Москва, ул. Боксёрская, 4',
      capacity: 2,
    ),
    Hall(
      id: 2,
      name: 'Ринг Б',
      address: 'Москва, ул. Боксёрская, 4',
      capacity: 4,
    ),
  ];
}

List<Training> buildSeedTrainings() {
  return [
    Training(
      id: 1,
      title: 'Спарринг вечером',
      hallId: 1,
      coachId: 1,
      disciplineId: 1,
      startsAt: DateTime.utc(2026, 11, 20, 15),
      endsAt: DateTime.utc(2026, 11, 20, 16, 30),
      priceRub: 3000,
      customerId: 1,
    ),
    Training(
      id: 2,
      title: 'Работа на мешке',
      hallId: 1,
      coachId: 2,
      disciplineId: 1,
      startsAt: DateTime.utc(2026, 11, 20, 17),
      endsAt: DateTime.utc(2026, 11, 20, 18),
      priceRub: 2500,
    ),
    Training(
      id: 3,
      title: 'Утренняя техника',
      hallId: 2,
      coachId: 3,
      disciplineId: 2,
      startsAt: DateTime.utc(2026, 11, 21, 7),
      endsAt: DateTime.utc(2026, 11, 21, 8, 30),
      priceRub: 4000,
      customerId: 2,
    ),
  ];
}
