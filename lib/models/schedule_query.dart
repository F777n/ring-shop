import 'query_codec.dart';

class ScheduleQuery {
  const ScheduleQuery({
    this.search = '',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  final String search;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  factory ScheduleQuery.fromUri(Uri uri) {
    final params = uri.queryParameters;
    return ScheduleQuery(
      search: params['search'] ?? '',
      sortAscending: params['sort'] != 'startsAt,desc',
      page: parsePage(params['page']),
      size: parsePageSize(params['size']),
      includeDeleted: params['deleted'] == '1',
    );
  }

  String toLocation(String path) {
    final params = <String, String>{};
    if (search.isNotEmpty) params['search'] = search;
    if (!sortAscending) params['sort'] = 'startsAt,desc';
    if (page != 1) params['page'] = '$page';
    if (size != 10) params['size'] = '$size';
    if (includeDeleted) params['deleted'] = '1';
    return buildLocation(path, params);
  }

  ScheduleQuery copyWith({
    String? search,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return ScheduleQuery(
      search: search ?? this.search,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? this.page,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduleQuery &&
        other.search == search &&
        other.sortAscending == sortAscending &&
        other.page == page &&
        other.size == size &&
        other.includeDeleted == includeDeleted;
  }

  @override
  int get hashCode => Object.hash(search, sortAscending, page, size, includeDeleted);
}
