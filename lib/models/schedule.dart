import '../domain/schedule_rules.dart';
import 'json_values.dart';

class Coach {
  const Coach({
    required this.id,
    required this.name,
    required this.rank,
    required this.phone,
    required this.disciplineIds,
    this.deletedAt,
  });

  final int id;
  final String name;
  final String rank;
  final String phone;
  final List<int> disciplineIds;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Coach copyWith({
    String? name,
    String? rank,
    String? phone,
    List<int>? disciplineIds,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Coach(
      id: id,
      name: name ?? this.name,
      rank: rank ?? this.rank,
      phone: phone ?? this.phone,
      disciplineIds: disciplineIds ?? this.disciplineIds,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rank': rank,
        'phone': phone,
        'disciplineIds': disciplineIds,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Coach.fromJson(Map<String, dynamic> json) {
    return Coach(
      id: readInt(json['id']),
      name: readString(json['name']),
      rank: readString(json['rank']),
      phone: readString(json['phone']),
      disciplineIds: readIntList(json['disciplineIds']),
      deletedAt: readDate(json['deletedAt']),
    );
  }
}

class Hall {
  const Hall({
    required this.id,
    required this.name,
    required this.address,
    required this.capacity,
    this.deletedAt,
  });

  final int id;
  final String name;
  final String address;
  final int capacity;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Hall copyWith({
    String? name,
    String? address,
    int? capacity,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Hall(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      capacity: capacity ?? this.capacity,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'capacity': capacity,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Hall.fromJson(Map<String, dynamic> json) {
    return Hall(
      id: readInt(json['id']),
      name: readString(json['name']),
      address: readString(json['address']),
      capacity: readInt(json['capacity']),
      deletedAt: readDate(json['deletedAt']),
    );
  }
}

class Training {
  const Training({
    required this.id,
    required this.title,
    required this.hallId,
    required this.coachId,
    required this.disciplineId,
    required this.startsAt,
    required this.endsAt,
    required this.priceRub,
    this.customerId,
    this.deletedAt,
  });

  final int id;
  final String title;
  final int hallId;
  final int coachId;
  final int disciplineId;
  final DateTime startsAt;
  final DateTime endsAt;
  final int priceRub;
  final int? customerId;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  TimeSlot get slot => TimeSlot(
        id: id,
        hallId: hallId,
        startsAt: startsAt,
        endsAt: endsAt,
        title: title,
        deleted: isDeleted,
      );

  Training copyWith({
    String? title,
    int? hallId,
    int? coachId,
    int? disciplineId,
    DateTime? startsAt,
    DateTime? endsAt,
    int? priceRub,
    Object? customerId = _keep,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Training(
      id: id,
      title: title ?? this.title,
      hallId: hallId ?? this.hallId,
      coachId: coachId ?? this.coachId,
      disciplineId: disciplineId ?? this.disciplineId,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      priceRub: priceRub ?? this.priceRub,
      customerId:
          customerId == _keep ? this.customerId : customerId as int?,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'hallId': hallId,
        'coachId': coachId,
        'disciplineId': disciplineId,
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
        'priceRub': priceRub,
        'customerId': customerId,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Training.fromJson(Map<String, dynamic> json) {
    final customer = readInt(json['customerId'], 0);
    return Training(
      id: readInt(json['id']),
      title: readString(json['title']),
      hallId: readInt(json['hallId']),
      coachId: readInt(json['coachId']),
      disciplineId: readInt(json['disciplineId']),
      startsAt: readDate(json['startsAt']) ?? DateTime.utc(2026),
      endsAt: readDate(json['endsAt']) ?? DateTime.utc(2026, 1, 1, 1),
      priceRub: readInt(json['priceRub']),
      customerId: customer > 0 ? customer : null,
      deletedAt: readDate(json['deletedAt']),
    );
  }
}

const _keep = Object();
