import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../data/schedule_seed.dart';
import '../domain/schedule_rules.dart';
import '../models/page_result.dart';
import '../models/schedule.dart';
import '../models/schedule_query.dart';
import 'memory_table.dart';

abstract interface class CoachRepository {
  Future<PageResult<Coach>> find(ScheduleQuery query);
  Future<List<Coach>> all();
  Future<Coach?> findById(int id);
  Future<Coach> create(Coach coach);
  Future<Coach> update(Coach coach);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
}

abstract interface class HallRepository {
  Future<PageResult<Hall>> find(ScheduleQuery query);
  Future<List<Hall>> all();
  Future<Hall?> findById(int id);
  Future<Hall> create(Hall hall);
  Future<Hall> update(Hall hall);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
}

abstract interface class TrainingRepository {
  Future<PageResult<Training>> find(ScheduleQuery query);
  Future<List<Training>> all();
  Future<Training?> findById(int id);
  Future<Training> create(Training training);
  Future<Training> update(Training training);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
}

class InMemoryCoachRepository implements CoachRepository {
  InMemoryCoachRepository({List<Coach>? coaches, Duration? latency})
      : _table = MemoryTable(
          items: coaches ?? buildSeedCoaches(),
          idOf: (item) => item.id,
          withId: (draft, id) => Coach(
            id: id,
            name: draft.name,
            rank: draft.rank,
            phone: draft.phone,
            disciplineIds: draft.disciplineIds,
            deletedAt: draft.deletedAt,
          ),
          latency: latency ?? const Duration(milliseconds: 250),
        );

  final MemoryTable<Coach> _table;

  @override
  Future<List<Coach>> all() async => _table.snapshot();

  @override
  Future<PageResult<Coach>> find(ScheduleQuery query) async {
    await _table.pause();
    final rows = _filter(
      _table.items,
      query,
      (item) => item.isDeleted,
      (item) => '${item.name} ${item.rank} ${item.phone}',
      (item) => item.name,
    );
    return pageOf(rows, page: query.page, size: query.size);
  }

  @override
  Future<Coach?> findById(int id) => _table.findById(id);

  @override
  Future<Coach> create(Coach coach) => _table.create(coach);

  @override
  Future<Coach> update(Coach coach) =>
      _table.update(coach, 'Тренер ${coach.id} не найден');

  @override
  Future<void> softDelete(int id) => _table.softDelete(
        id,
        (item) => item.copyWith(deletedAt: DateTime.now().toUtc()),
        'Тренер $id не найден',
      );

  @override
  Future<void> hardDelete(int id) =>
      _table.hardDelete(id, 'Тренер $id не найден');

  @override
  Future<void> restore(int id) => _table.restore(
        id,
        (item) => item.copyWith(clearDeletedAt: true),
        'Тренер $id не найден',
      );
}

class InMemoryHallRepository implements HallRepository {
  InMemoryHallRepository({List<Hall>? halls, Duration? latency})
      : _table = MemoryTable(
          items: halls ?? buildSeedHalls(),
          idOf: (item) => item.id,
          withId: (draft, id) => Hall(
            id: id,
            name: draft.name,
            address: draft.address,
            capacity: draft.capacity,
            deletedAt: draft.deletedAt,
          ),
          latency: latency ?? const Duration(milliseconds: 250),
        );

  final MemoryTable<Hall> _table;

  @override
  Future<List<Hall>> all() async => _table.snapshot();

  @override
  Future<PageResult<Hall>> find(ScheduleQuery query) async {
    await _table.pause();
    final rows = _filter(
      _table.items,
      query,
      (item) => item.isDeleted,
      (item) => '${item.name} ${item.address}',
      (item) => item.name,
    );
    return pageOf(rows, page: query.page, size: query.size);
  }

  @override
  Future<Hall?> findById(int id) => _table.findById(id);

  @override
  Future<Hall> create(Hall hall) => _table.create(hall);

  @override
  Future<Hall> update(Hall hall) =>
      _table.update(hall, 'Зал ${hall.id} не найден');

  @override
  Future<void> softDelete(int id) => _table.softDelete(
        id,
        (item) => item.copyWith(deletedAt: DateTime.now().toUtc()),
        'Зал $id не найден',
      );

  @override
  Future<void> hardDelete(int id) => _table.hardDelete(id, 'Зал $id не найден');

  @override
  Future<void> restore(int id) => _table.restore(
        id,
        (item) => item.copyWith(clearDeletedAt: true),
        'Зал $id не найден',
      );
}

class InMemoryTrainingRepository implements TrainingRepository {
  InMemoryTrainingRepository({List<Training>? trainings, Duration? latency})
      : _table = MemoryTable(
          items: trainings ?? buildSeedTrainings(),
          idOf: (item) => item.id,
          withId: (draft, id) => Training(
            id: id,
            title: draft.title,
            hallId: draft.hallId,
            coachId: draft.coachId,
            disciplineId: draft.disciplineId,
            startsAt: draft.startsAt,
            endsAt: draft.endsAt,
            priceRub: draft.priceRub,
            customerId: draft.customerId,
            deletedAt: draft.deletedAt,
          ),
          latency: latency ?? const Duration(milliseconds: 250),
        );

  final MemoryTable<Training> _table;

  @override
  Future<List<Training>> all() async => _table.snapshot();

  @override
  Future<PageResult<Training>> find(ScheduleQuery query) async {
    await _table.pause();
    final rows = _filter(
      _table.items,
      query,
      (item) => item.isDeleted,
      (item) => item.title,
      (item) => item.startsAt.toIso8601String(),
    );
    return pageOf(rows, page: query.page, size: query.size);
  }

  @override
  Future<Training?> findById(int id) => _table.findById(id);

  @override
  Future<Training> create(Training training) async {
    _guard(training);
    return _table.create(training);
  }

  @override
  Future<Training> update(Training training) async {
    _guard(training, exceptId: training.id);
    return _table.update(training, 'Тренировка ${training.id} не найдена');
  }

  @override
  Future<void> softDelete(int id) => _table.softDelete(
        id,
        (item) => item.copyWith(deletedAt: DateTime.now().toUtc()),
        'Тренировка $id не найдена',
      );

  @override
  Future<void> hardDelete(int id) =>
      _table.hardDelete(id, 'Тренировка $id не найдена');

  @override
  Future<void> restore(int id) => _table.restore(
        id,
        (item) => item.copyWith(clearDeletedAt: true),
        'Тренировка $id не найдена',
      );

  void _guard(Training training, {int? exceptId}) {
    final conflict = conflictingSlot(
      _table.items.map((item) => item.slot),
      training.slot,
    );
    if (conflict != null && conflict.id != exceptId) {
      throw ConflictException(
        'Зал занят: «${conflict.title}» уже стоит на это время.',
      );
    }
  }
}

List<T> _filter<T>(
  List<T> source,
  ScheduleQuery query,
  bool Function(T item) deleted,
  String Function(T item) searchText,
  String Function(T item) sortText,
) {
  final needle = query.search.trim().toLowerCase();
  final rows = source.where((item) {
    if (!query.includeDeleted && deleted(item)) return false;
    if (needle.isEmpty) return true;
    return searchText(item).toLowerCase().contains(needle);
  }).toList();
  rows.sort((a, b) => sortText(a).compareTo(sortText(b)));
  if (!query.sortAscending) {
    final copy = rows.reversed.toList();
    return copy;
  }
  return rows;
}

class ApiCoachRepository implements CoachRepository {
  ApiCoachRepository(Dio dio) : _dio = dio;
  final Dio _dio;

  @override
  Future<PageResult<Coach>> find(ScheduleQuery query) =>
      _find(_dio, '/coaches', query, Coach.fromJson);

  @override
  Future<List<Coach>> all() => _all(_dio, '/coaches', Coach.fromJson);

  @override
  Future<Coach?> findById(int id) => _byId(_dio, '/coaches/$id', Coach.fromJson);

  @override
  Future<Coach> create(Coach coach) =>
      _save(_dio, '/coaches', coach.toJson(), Coach.fromJson, creating: true);

  @override
  Future<Coach> update(Coach coach) =>
      _save(_dio, '/coaches/${coach.id}', coach.toJson(), Coach.fromJson);

  @override
  Future<void> softDelete(int id) => _dio.delete('/coaches/$id');

  @override
  Future<void> hardDelete(int id) =>
      _dio.delete('/coaches/$id', queryParameters: {'hard': true});

  @override
  Future<void> restore(int id) => _dio.post('/coaches/$id/restore');
}

class ApiHallRepository implements HallRepository {
  ApiHallRepository(Dio dio) : _dio = dio;
  final Dio _dio;

  @override
  Future<PageResult<Hall>> find(ScheduleQuery query) =>
      _find(_dio, '/halls', query, Hall.fromJson);

  @override
  Future<List<Hall>> all() => _all(_dio, '/halls', Hall.fromJson);

  @override
  Future<Hall?> findById(int id) => _byId(_dio, '/halls/$id', Hall.fromJson);

  @override
  Future<Hall> create(Hall hall) =>
      _save(_dio, '/halls', hall.toJson(), Hall.fromJson, creating: true);

  @override
  Future<Hall> update(Hall hall) =>
      _save(_dio, '/halls/${hall.id}', hall.toJson(), Hall.fromJson);

  @override
  Future<void> softDelete(int id) => _dio.delete('/halls/$id');

  @override
  Future<void> hardDelete(int id) =>
      _dio.delete('/halls/$id', queryParameters: {'hard': true});

  @override
  Future<void> restore(int id) => _dio.post('/halls/$id/restore');
}

class ApiTrainingRepository implements TrainingRepository {
  ApiTrainingRepository(Dio dio) : _dio = dio;
  final Dio _dio;

  @override
  Future<PageResult<Training>> find(ScheduleQuery query) =>
      _find(_dio, '/trainings', query, Training.fromJson);

  @override
  Future<List<Training>> all() => _all(_dio, '/trainings', Training.fromJson);

  @override
  Future<Training?> findById(int id) =>
      _byId(_dio, '/trainings/$id', Training.fromJson);

  @override
  Future<Training> create(Training training) => _save(
      _dio, '/trainings', training.toJson(), Training.fromJson,
      creating: true);

  @override
  Future<Training> update(Training training) => _save(
      _dio, '/trainings/${training.id}', training.toJson(), Training.fromJson);

  @override
  Future<void> softDelete(int id) => _dio.delete('/trainings/$id');

  @override
  Future<void> hardDelete(int id) =>
      _dio.delete('/trainings/$id', queryParameters: {'hard': true});

  @override
  Future<void> restore(int id) => _dio.post('/trainings/$id/restore');
}

Future<PageResult<T>> _find<T>(
  Dio dio,
  String path,
  ScheduleQuery query,
  T Function(Map<String, dynamic>) decode,
) {
  return guard(() async {
    final response = await dio.get(path, queryParameters: {
      if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
      'sort': 'name,${query.sortAscending ? 'asc' : 'desc'}',
      'page': query.page,
      'size': query.size,
      if (query.includeDeleted) 'includeDeleted': true,
    });
    final map = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    final raw = map['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => decode(Map<String, dynamic>.from(item)))
            .toList()
        : <T>[];
    int number(Object? value, int fallback) =>
        value is int ? value : int.tryParse('$value') ?? fallback;
    return PageResult(
      items: items,
      page: number(map['page'], query.page),
      size: number(map['size'], query.size),
      total: number(map['total'], items.length),
    );
  });
}

Future<List<T>> _all<T>(
  Dio dio,
  String path,
  T Function(Map<String, dynamic>) decode,
) async {
  final page = await _find(
    dio,
    path,
    const ScheduleQuery(size: 50),
    decode,
  );
  return page.items;
}

Future<T?> _byId<T>(
  Dio dio,
  String path,
  T Function(Map<String, dynamic>) decode,
) {
  return guard(() async {
    try {
      final response = await dio.get(path);
      if (response.data is Map) {
        return decode(Map<String, dynamic>.from(response.data as Map));
      }
      return null;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  });
}

Future<T> _save<T>(
  Dio dio,
  String path,
  Map<String, dynamic> body,
  T Function(Map<String, dynamic>) decode, {
  bool creating = false,
}) {
  return guard(() async {
    final response = creating
        ? await dio.post(path, data: body)
        : await dio.put(path, data: body);
    return decode(Map<String, dynamic>.from(response.data as Map));
  });
}
