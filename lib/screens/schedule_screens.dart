import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/access.dart';
import '../domain/schedule_rules.dart';
import '../forms/field_spec.dart';
import '../forms/spec_form_screen.dart';
import '../forms/validators.dart';
import '../models/customer.dart';
import '../models/page_result.dart';
import '../models/schedule.dart';
import '../models/schedule_query.dart';
import '../repositories/directory_repositories.dart';
import '../repositories/schedule_repository.dart';
import '../state/auth_notifier.dart';
import '../widgets/status_views.dart';

class TrainingListScreen extends StatelessWidget {
  const TrainingListScreen({super.key, required this.query});

  final ScheduleQuery query;

  @override
  Widget build(BuildContext context) {
    return _ScheduleList<Training>(
      title: 'Тренировки',
      subtitle:
          'Зал нельзя занять дважды на одно время. Цена считается со скидкой карты.',
      query: query,
      path: '/trainings',
      load: (context, item) => context.read<TrainingRepository>().find(item),
      empty: 'Тренировок по этому запросу нет.',
      titleOf: (item) => item.title,
      linesOf: (item) => _trainingLines(item),
    );
  }
}

class CoachListScreen extends StatelessWidget {
  const CoachListScreen({super.key, required this.query});

  final ScheduleQuery query;

  @override
  Widget build(BuildContext context) {
    return _ScheduleList<Coach>(
      title: 'Тренеры',
      subtitle: 'Тренер ведёт дисциплины. Связь многие ко многим.',
      query: query,
      path: '/coaches',
      load: (context, item) => context.read<CoachRepository>().find(item),
      empty: 'Тренеров по этому запросу нет.',
      titleOf: (item) => item.name,
      linesOf: (item) => ['${item.rank} · ${item.phone}'],
    );
  }
}

class HallListScreen extends StatelessWidget {
  const HallListScreen({super.key, required this.query});

  final ScheduleQuery query;

  @override
  Widget build(BuildContext context) {
    return _ScheduleList<Hall>(
      title: 'Залы',
      subtitle: 'Ринг, в котором проходит тренировка. Связь один ко многим.',
      query: query,
      path: '/halls',
      load: (context, item) => context.read<HallRepository>().find(item),
      empty: 'Залов по этому запросу нет.',
      titleOf: (item) => item.name,
      linesOf: (item) => ['${item.address} · мест ${item.capacity}'],
    );
  }
}

class TrainingFormScreen extends StatelessWidget {
  const TrainingFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<TrainingRepository>();
    return SpecFormScreen(
      fallback: '/trainings',
      locationFor: (savedId) => '/trainings',
      load: () => _load(context, repository),
      save: (values) => _save(repository, values),
    );
  }

  Future<FormBlueprint> _load(
      BuildContext context, TrainingRepository repository) async {
    final hallsRepo = context.read<HallRepository>();
    final coachesRepo = context.read<CoachRepository>();
    final disciplinesRepo = context.read<DisciplineRepository>();
    final customersRepo = context.read<CustomerRepository>();
    final training = id == null ? null : await repository.findById(id!);
    if (id != null && training == null) {
      throw StateError('Тренировка с номером $id не найдена.');
    }
    final halls = await hallsRepo.all();
    final coaches = await coachesRepo.all();
    final disciplines = await disciplinesRepo.all();
    final customers = await customersRepo.all();
    return FormBlueprint(
      title: id == null ? 'Новая тренировка' : 'Изменение тренировки',
      submitLabel: id == null ? 'Создать' : 'Сохранить',
      values: {
        'title': training?.title ?? '',
        'hallId': training?.hallId,
        'coachId': training?.coachId,
        'disciplineId': training?.disciplineId,
        'customerId': training?.customerId,
        'startsAt': _stamp(training?.startsAt),
        'endsAt': _stamp(training?.endsAt),
        'priceRub': training == null ? '' : '${training.priceRub}',
      },
      fields: (values) {
        final price = int.tryParse(textValue(values, 'priceRub')) ?? 0;
        final customerId = intValue(values, 'customerId');
        final customer = customers.cast<Customer?>().firstWhere(
              (item) => item?.id == customerId,
              orElse: () => null,
            );
        final charged = customer == null
            ? price
            : chargedPrice(
                price,
                discountPercent: customer.card.discountPercent,
                cardActive: customer.card.active,
              );
        return [
          TextFieldSpec(
            id: 'title',
            label: 'Название',
            initialValue: textValue(values, 'title'),
            validator: (value, _) =>
                requiredText(value, message: 'Укажите название') ??
                lengthBetween(value, 2, 80),
          ),
          IntChoiceSpec(
            id: 'hallId',
            label: 'Зал',
            value: intValue(values, 'hallId'),
            options: [
              for (final hall in halls)
                if (!hall.isDeleted) ChoiceOption(hall.id, hall.name),
            ],
            validator: (value) => value == null ? 'Выберите зал' : null,
          ),
          IntChoiceSpec(
            id: 'coachId',
            label: 'Тренер',
            value: intValue(values, 'coachId'),
            options: [
              for (final coach in coaches)
                if (!coach.isDeleted) ChoiceOption(coach.id, coach.name),
            ],
            validator: (value) => value == null ? 'Выберите тренера' : null,
          ),
          IntChoiceSpec(
            id: 'disciplineId',
            label: 'Дисциплина',
            value: intValue(values, 'disciplineId'),
            options: [
              for (final item in disciplines)
                if (!item.isDeleted) ChoiceOption(item.id, item.name),
            ],
            validator: (value) => value == null ? 'Выберите дисциплину' : null,
          ),
          IntChoiceSpec(
            id: 'customerId',
            label: 'Клиент',
            emptyLabel: 'Без записи',
            value: intValue(values, 'customerId'),
            options: [
              for (final item in customers)
                if (!item.isDeleted) ChoiceOption(item.id, item.fullName),
            ],
            validator: (_) => null,
          ),
          TextFieldSpec(
            id: 'startsAt',
            label: 'Начало',
            hint: '2026-11-20T18:00',
            initialValue: textValue(values, 'startsAt'),
            validator: (value, _) => _timeText(value, 'Укажите начало'),
          ),
          TextFieldSpec(
            id: 'endsAt',
            label: 'Конец',
            hint: '2026-11-20T19:30',
            initialValue: textValue(values, 'endsAt'),
            validator: (value, texts) {
              final message = _timeText(value, 'Укажите конец');
              if (message != null) return message;
              final start = DateTime.tryParse(texts['startsAt'] ?? '');
              final end = DateTime.tryParse(value?.trim() ?? '');
              if (start != null && end != null && !end.isAfter(start)) {
                return 'Конец должен быть позже начала';
              }
              return null;
            },
          ),
          TextFieldSpec(
            id: 'priceRub',
            label: 'Цена, ₽',
            compact: true,
            digitsOnly: true,
            initialValue: textValue(values, 'priceRub'),
            validator: (value, _) => intInRange(
              value,
              min: 1,
              max: 100000,
              empty: 'Укажите цену',
            ),
          ),
          SectionSpec(id: 'price', title: 'К оплате $charged ₽'),
        ];
      },
    );
  }

  Future<int> _save(
      TrainingRepository repository, Map<String, Object?> values) async {
    final training = Training(
      id: id ?? 0,
      title: textValue(values, 'title').trim(),
      hallId: intValue(values, 'hallId') ?? 0,
      coachId: intValue(values, 'coachId') ?? 0,
      disciplineId: intValue(values, 'disciplineId') ?? 0,
      customerId: intValue(values, 'customerId'),
      startsAt: DateTime.parse(textValue(values, 'startsAt').trim()),
      endsAt: DateTime.parse(textValue(values, 'endsAt').trim()),
      priceRub: int.parse(textValue(values, 'priceRub').trim()),
    );
    final saved = id == null
        ? await repository.create(training)
        : await repository.update(training);
    return saved.id;
  }
}

class CoachFormScreen extends StatelessWidget {
  const CoachFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CoachRepository>();
    return SpecFormScreen(
      fallback: '/coaches',
      locationFor: (savedId) => '/coaches',
      load: () => _load(context, repository),
      save: (values) => _save(repository, values),
    );
  }

  Future<FormBlueprint> _load(
      BuildContext context, CoachRepository repository) async {
    final disciplinesRepo = context.read<DisciplineRepository>();
    final coach = id == null ? null : await repository.findById(id!);
    if (id != null && coach == null) {
      throw StateError('Тренер с номером $id не найден.');
    }
    final disciplines = await disciplinesRepo.all();
    return FormBlueprint(
      title: id == null ? 'Новый тренер' : 'Изменение тренера',
      submitLabel: id == null ? 'Создать' : 'Сохранить',
      values: {
        'name': coach?.name ?? '',
        'rank': coach?.rank ?? '',
        'phone': coach?.phone ?? '+7',
        'disciplineIds': coach?.disciplineIds ?? <int>[],
      },
      fields: (values) => [
        TextFieldSpec(
          id: 'name',
          label: 'Имя',
          initialValue: textValue(values, 'name'),
          validator: (value, _) =>
              requiredText(value, message: 'Укажите имя') ??
              lengthBetween(value, 2, 80),
        ),
        TextFieldSpec(
          id: 'rank',
          label: 'Разряд',
          initialValue: textValue(values, 'rank'),
          validator: (value, _) =>
              requiredText(value, message: 'Укажите разряд') ??
              lengthBetween(value, 2, 20),
        ),
        TextFieldSpec(
          id: 'phone',
          label: 'Телефон',
          initialValue: textValue(values, 'phone'),
          validator: (value, _) => phoneText(value),
        ),
        MultiSpec(
          id: 'disciplineIds',
          label: 'Дисциплины',
          values: _ids(values['disciplineIds']),
          options: [
            for (final item in disciplines)
              if (!item.isDeleted) ChoiceOption(item.id, item.name),
          ],
          validator: (value) =>
              value == null || value.isEmpty ? 'Выберите дисциплины' : null,
        ),
      ],
    );
  }

  Future<int> _save(
      CoachRepository repository, Map<String, Object?> values) async {
    final coach = Coach(
      id: id ?? 0,
      name: textValue(values, 'name').trim(),
      rank: textValue(values, 'rank').trim(),
      phone: textValue(values, 'phone').trim(),
      disciplineIds: _ids(values['disciplineIds']),
    );
    final saved =
        id == null ? await repository.create(coach) : await repository.update(coach);
    return saved.id;
  }
}

class HallFormScreen extends StatelessWidget {
  const HallFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<HallRepository>();
    return SpecFormScreen(
      fallback: '/halls',
      locationFor: (savedId) => '/halls',
      load: () => _load(repository),
      save: (values) => _save(repository, values),
    );
  }

  Future<FormBlueprint> _load(HallRepository repository) async {
    final hall = id == null ? null : await repository.findById(id!);
    if (id != null && hall == null) {
      throw StateError('Зал с номером $id не найден.');
    }
    return FormBlueprint(
      title: id == null ? 'Новый зал' : 'Изменение зала',
      submitLabel: id == null ? 'Создать' : 'Сохранить',
      values: {
        'name': hall?.name ?? '',
        'address': hall?.address ?? '',
        'capacity': hall == null ? '' : '${hall.capacity}',
      },
      fields: (values) => [
        TextFieldSpec(
          id: 'name',
          label: 'Название',
          initialValue: textValue(values, 'name'),
          validator: (value, _) =>
              requiredText(value, message: 'Укажите название') ??
              lengthBetween(value, 2, 40),
        ),
        TextFieldSpec(
          id: 'address',
          label: 'Адрес',
          initialValue: textValue(values, 'address'),
          validator: (value, _) =>
              requiredText(value, message: 'Укажите адрес') ??
              lengthBetween(value, 4, 120),
        ),
        TextFieldSpec(
          id: 'capacity',
          label: 'Мест',
          compact: true,
          digitsOnly: true,
          initialValue: textValue(values, 'capacity'),
          validator: (value, _) => intInRange(
            value,
            min: 1,
            max: 50,
            empty: 'Укажите число мест',
          ),
        ),
      ],
    );
  }

  Future<int> _save(HallRepository repository, Map<String, Object?> values) async {
    final hall = Hall(
      id: id ?? 0,
      name: textValue(values, 'name').trim(),
      address: textValue(values, 'address').trim(),
      capacity: int.parse(textValue(values, 'capacity').trim()),
    );
    final saved =
        id == null ? await repository.create(hall) : await repository.update(hall);
    return saved.id;
  }
}

class _ScheduleList<T> extends StatefulWidget {
  const _ScheduleList({
    required this.title,
    required this.subtitle,
    required this.query,
    required this.path,
    required this.load,
    required this.empty,
    required this.titleOf,
    required this.linesOf,
  });

  final String title;
  final String subtitle;
  final ScheduleQuery query;
  final String path;
  final Future<PageResult<T>> Function(BuildContext context, ScheduleQuery query)
      load;
  final String empty;
  final String Function(T item) titleOf;
  final List<String> Function(T item) linesOf;

  @override
  State<_ScheduleList<T>> createState() => _ScheduleListState<T>();
}

class _ScheduleListState<T> extends State<_ScheduleList<T>> {
  late Future<PageResult<T>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load(context, widget.query);
  }

  @override
  void didUpdateWidget(covariant _ScheduleList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _future = widget.load(context, widget.query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final canEdit = auth.can(Operation.manageCatalog);
    return FutureBuilder<PageResult<T>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(message: 'Загружаем расписание…');
        }
        if (snapshot.hasError) {
          return ErrorView(
            message: '${snapshot.error}',
            onRetry: () => setState(() {
              _future = widget.load(context, widget.query);
            }),
          );
        }
        final page = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(widget.subtitle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.path == '/trainings' && canEdit) ...[
                  OutlinedButton(
                    onPressed: () => context.go('/coaches'),
                    child: const Text('Тренеры'),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/halls'),
                    child: const Text('Залы'),
                  ),
                ],
                if (canEdit)
                  FilledButton(
                    onPressed: () => context.go('${widget.path}/new'),
                    child: const Text('Добавить'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Поиск',
                prefixIcon: Icon(Icons.search),
              ),
              controller: TextEditingController(text: widget.query.search),
              onSubmitted: (value) => context.go(
                widget.query.copyWith(search: value, page: 1).toLocation(widget.path),
              ),
            ),
            const SizedBox(height: 12),
            if (page.items.isEmpty)
              EmptyView(title: 'Пусто', message: widget.empty)
            else
              for (final item in page.items)
                Card(
                  child: ListTile(
                    title: Text(
                      widget.titleOf(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(widget.linesOf(item).join('\n')),
                    trailing: canEdit
                        ? IconButton(
                            tooltip: 'Изменить',
                            onPressed: () => context.go(
                                '${widget.path}/${_idOf(item)}/edit'),
                            icon: const Icon(Icons.edit_outlined),
                          )
                        : null,
                  ),
                ),
          ],
        );
      },
    );
  }

  int _idOf(T item) {
    final dynamic value = item;
    return value.id as int;
  }
}

List<String> _trainingLines(Training item) {
  return [
    '${_clock(item.startsAt)}–${_clock(item.endsAt)}',
    'Цена ${item.priceRub} ₽, со скидкой карты — в форме',
  ];
}

String _clock(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} $hour:$minute';
}

String _stamp(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}T${two(local.hour)}:${two(local.minute)}';
}

String? _timeText(String? value, String message) {
  final required = requiredText(value, message: message);
  if (required != null) return required;
  if (DateTime.tryParse(value!.trim()) == null) {
    return 'Формат 2026-11-20T18:00';
  }
  return null;
}

List<int> _ids(Object? value) {
  if (value is List<int>) return value;
  if (value is List) {
    return value.map((item) => item is int ? item : int.tryParse('$item') ?? 0).where((id) => id > 0).toList();
  }
  return const [];
}
