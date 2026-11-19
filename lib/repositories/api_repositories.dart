import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/brand.dart';
import '../models/brand_query.dart';
import '../models/category.dart';
import '../models/category_query.dart';
import '../models/customer.dart';
import '../models/customer_query.dart';
import '../models/discipline.dart';
import '../models/discipline_query.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import 'brand_repository.dart';
import 'directory_repositories.dart';
import 'product_repository.dart';

class _Api {
  _Api(this.dio);

  final Dio dio;
  CancelToken? _list;

  CancelToken replaceListToken() {
    _list?.cancel();
    return _list = CancelToken();
  }

  Future<T> run<T>(Future<T> Function() action) => guard(action);
}

Map<String, dynamic> _pageQuery({
  required String search,
  required String sortField,
  required bool ascending,
  required int page,
  required int size,
  required bool includeDeleted,
  Map<String, Object?> extra = const {},
}) {
  return {
    if (search.trim().isNotEmpty) 'search': search.trim(),
    'sort': '$sortField,${ascending ? 'asc' : 'desc'}',
    'page': page,
    'size': size,
    if (includeDeleted) 'includeDeleted': true,
    for (final entry in extra.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}

PageResult<T> _page<T>(
    dynamic data, T Function(Map<String, dynamic>) decode, int size) {
  final map =
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
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
    page: number(map['page'], 1),
    size: number(map['size'], size),
    total: number(map['total'], items.length),
  );
}

Map<String, dynamic> _map(dynamic data) =>
    data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

class ApiProductRepository implements ProductRepository {
  ApiProductRepository(Dio dio) : _api = _Api(dio);

  final _Api _api;

  @override
  Future<PageResult<Product>> find(ProductQuery query) {
    return _api.run(() async {
      final response = await _api.dio.get(
        '/products',
        queryParameters: _pageQuery(
          search: query.search,
          sortField: query.sortField,
          ascending: query.sortAscending,
          page: query.page,
          size: query.size,
          includeDeleted: query.includeDeleted,
          extra: {
            'categoryId': query.categoryId,
            'brandId': query.brandId,
            'yearFrom': query.yearFrom,
            'yearTo': query.yearTo,
          },
        ),
        cancelToken: _api.replaceListToken(),
      );
      return _page(response.data, Product.fromJson, query.size);
    });
  }

  @override
  Future<List<Product>> all() {
    return _api.run(() async {
      final response = await _api.dio.get('/products', queryParameters: {
        'page': 1,
        'size': 500,
        'includeDeleted': true,
        'sort': 'name,asc',
      });
      return _page(response.data, Product.fromJson, 500).items;
    });
  }

  @override
  Future<Product?> findById(int id) {
    return _api.run(() async {
      try {
        final response = await _api.dio.get('/products/$id');
        return Product.fromJson(_map(response.data));
      } on DioException catch (error) {
        if (mapDioError(error) is NotFoundException) return null;
        rethrow;
      }
    });
  }

  @override
  Future<int> countLinked({int? brandId, int? categoryId, int? disciplineId}) {
    if (brandId == null && categoryId == null && disciplineId == null) {
      return Future.value(0);
    }
    return _api.run(() async {
      final response = await _api.dio.get('/products', queryParameters: {
        if (brandId != null) 'brandId': brandId,
        if (categoryId != null) 'categoryId': categoryId,
        if (disciplineId != null) 'disciplineId': disciplineId,
        'page': 1,
        'size': 1,
        'includeDeleted': true,
        'sort': 'name,asc',
      });
      return _page(response.data, Product.fromJson, 1).total;
    });
  }

  @override
  Future<bool> isSkuTaken(String sku, {int? exceptId}) {
    return _api.run(() async {
      final response =
          await _api.dio.get('/products/sku-taken', queryParameters: {
        'sku': sku,
        if (exceptId != null) 'exceptId': exceptId,
      });
      return _map(response.data)['taken'] == true;
    });
  }

  @override
  Future<Product> create(Product product) {
    return _api.run(() async {
      final response =
          await _api.dio.post('/products', data: _productBody(product));
      return Product.fromJson(_map(response.data));
    });
  }

  @override
  Future<Product> update(Product product) {
    return _api.run(() async {
      final response = await _api.dio
          .put('/products/${product.id}', data: _productBody(product));
      return Product.fromJson(_map(response.data));
    });
  }

  @override
  Future<Product> sell(int id) {
    return _api.run(() async {
      final response = await _api.dio.post('/products/$id/sell');
      return Product.fromJson(_map(response.data));
    });
  }

  @override
  Future<void> softDelete(int id) =>
      _api.run(() => _api.dio.delete('/products/$id'));

  @override
  Future<void> hardDelete(int id) => _api.run(
      () => _api.dio.delete('/products/$id', queryParameters: {'hard': true}));

  @override
  Future<void> restore(int id) =>
      _api.run(() => _api.dio.post('/products/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) {
    return _api.run(() async {
      final response =
          await _api.dio.post('/products/bulk-delete', data: {'ids': ids});
      final deleted = _map(response.data)['deleted'];
      return deleted is int ? deleted : int.tryParse('$deleted') ?? 0;
    });
  }

  Map<String, dynamic> _productBody(Product product) {
    final json = product.toJson();
    json.remove('id');
    json.remove('deletedAt');
    return json;
  }
}

class _DirectoryCache<T> {
  List<T>? _items;

  void invalidate() => _items = null;

  Future<List<T>> get(Future<List<T>> Function() load) async {
    final cached = _items;
    if (cached != null) return cached;
    final loaded = await load();
    _items = loaded;
    return loaded;
  }
}

class ApiBrandRepository implements BrandRepository {
  ApiBrandRepository(Dio dio)
      : _api = _Api(dio),
        _cache = _DirectoryCache<Brand>();

  final _Api _api;
  final _DirectoryCache<Brand> _cache;

  @override
  Future<PageResult<Brand>> find(BrandQuery query) {
    return _api.run(() async {
      final response = await _api.dio.get(
        '/brands',
        queryParameters: _pageQuery(
          search: query.search,
          sortField: query.sortField,
          ascending: query.sortAscending,
          page: query.page,
          size: query.size,
          includeDeleted: query.includeDeleted,
          extra: {
            'country': query.country,
            'yearFrom': query.yearFrom,
            'yearTo': query.yearTo,
          },
        ),
        cancelToken: _api.replaceListToken(),
      );
      return _page(response.data, Brand.fromJson, query.size);
    });
  }

  @override
  Future<List<Brand>> all() => _cache.get(() => _loadAll());

  Future<List<Brand>> _loadAll() {
    return _api.run(() async {
      final response = await _api.dio.get('/brands', queryParameters: {
        'page': 1,
        'size': 500,
        'includeDeleted': true,
        'sort': 'name,asc',
      });
      return _page(response.data, Brand.fromJson, 500).items;
    });
  }

  @override
  Future<Brand?> findById(int id) => _one('/brands/$id', Brand.fromJson);

  @override
  Future<Brand> create(Brand brand) =>
      _write('post', '/brands', brand.toJson());

  @override
  Future<Brand> update(Brand brand) =>
      _write('put', '/brands/${brand.id}', brand.toJson());

  Future<Brand> _write(String method, String path, Map<String, dynamic> json) {
    json.remove('id');
    json.remove('deletedAt');
    return _api.run(() async {
      final response = method == 'post'
          ? await _api.dio.post(path, data: json)
          : await _api.dio.put(path, data: json);
      _cache.invalidate();
      return Brand.fromJson(_map(response.data));
    });
  }

  @override
  Future<void> softDelete(int id) =>
      _drop(() => _api.dio.delete('/brands/$id'));

  @override
  Future<void> hardDelete(int id) => _drop(
      () => _api.dio.delete('/brands/$id', queryParameters: {'hard': true}));

  @override
  Future<void> restore(int id) =>
      _drop(() => _api.dio.post('/brands/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) => _bulk('/brands/bulk-delete', ids);

  Future<Brand?> _one(
      String path, Brand Function(Map<String, dynamic>) decode) {
    return _api.run(() async {
      try {
        final response = await _api.dio.get(path);
        return decode(_map(response.data));
      } on DioException catch (error) {
        if (mapDioError(error) is NotFoundException) return null;
        rethrow;
      }
    });
  }

  Future<void> _drop(Future<Response<dynamic>> Function() action) {
    return _api.run(() async {
      await action();
      _cache.invalidate();
    });
  }

  Future<int> _bulk(String path, List<int> ids) {
    return _api.run(() async {
      final response = await _api.dio.post(path, data: {'ids': ids});
      _cache.invalidate();
      final deleted = _map(response.data)['deleted'];
      return deleted is int ? deleted : int.tryParse('$deleted') ?? 0;
    });
  }
}

class ApiCategoryRepository implements CategoryRepository {
  ApiCategoryRepository(Dio dio)
      : _api = _Api(dio),
        _cache = _DirectoryCache<Category>();

  final _Api _api;
  final _DirectoryCache<Category> _cache;

  @override
  Future<PageResult<Category>> find(CategoryQuery query) {
    return _api.run(() async {
      final response = await _api.dio.get(
        '/categories',
        queryParameters: _pageQuery(
          search: query.search,
          sortField: query.sortField,
          ascending: query.sortAscending,
          page: query.page,
          size: query.size,
          includeDeleted: query.includeDeleted,
          extra: {
            'kind': query.kind,
            'yearFrom': query.yearFrom,
            'yearTo': query.yearTo,
          },
        ),
        cancelToken: _api.replaceListToken(),
      );
      return _page(response.data, Category.fromJson, query.size);
    });
  }

  @override
  Future<List<Category>> all() => _cache.get(_loadAll);

  Future<List<Category>> _loadAll() {
    return _api.run(() async {
      final response = await _api.dio.get('/categories', queryParameters: {
        'page': 1,
        'size': 500,
        'includeDeleted': true,
        'sort': 'name,asc',
      });
      return _page(response.data, Category.fromJson, 500).items;
    });
  }

  @override
  Future<Category?> findById(int id) =>
      _optional('/categories/$id', Category.fromJson);

  @override
  Future<bool> isCodeTaken(String code, {int? exceptId}) async {
    final needle = code.trim().toLowerCase();
    final rows = await all();
    return rows.any((item) =>
        item.id != exceptId && item.code.trim().toLowerCase() == needle);
  }

  @override
  Future<Category> create(Category category) =>
      _save('post', '/categories', category.toJson());

  @override
  Future<Category> update(Category category) =>
      _save('put', '/categories/${category.id}', category.toJson());

  Future<Category> _save(
      String method, String path, Map<String, dynamic> json) {
    json.remove('id');
    json.remove('deletedAt');
    return _api.run(() async {
      final response = method == 'post'
          ? await _api.dio.post(path, data: json)
          : await _api.dio.put(path, data: json);
      _cache.invalidate();
      return Category.fromJson(_map(response.data));
    });
  }

  @override
  Future<void> softDelete(int id) =>
      _mutate(() => _api.dio.delete('/categories/$id'));

  @override
  Future<void> hardDelete(int id) => _mutate(() =>
      _api.dio.delete('/categories/$id', queryParameters: {'hard': true}));

  @override
  Future<void> restore(int id) =>
      _mutate(() => _api.dio.post('/categories/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) =>
      _bulk('/categories/bulk-delete', ids);

  Future<Category?> _optional(
      String path, Category Function(Map<String, dynamic>) decode) {
    return _api.run(() async {
      try {
        final response = await _api.dio.get(path);
        return decode(_map(response.data));
      } on DioException catch (error) {
        if (mapDioError(error) is NotFoundException) return null;
        rethrow;
      }
    });
  }

  Future<void> _mutate(Future<Response<dynamic>> Function() action) {
    return _api.run(() async {
      await action();
      _cache.invalidate();
    });
  }

  Future<int> _bulk(String path, List<int> ids) {
    return _api.run(() async {
      final response = await _api.dio.post(path, data: {'ids': ids});
      _cache.invalidate();
      final deleted = _map(response.data)['deleted'];
      return deleted is int ? deleted : int.tryParse('$deleted') ?? 0;
    });
  }
}

class ApiDisciplineRepository implements DisciplineRepository {
  ApiDisciplineRepository(Dio dio)
      : _api = _Api(dio),
        _cache = _DirectoryCache<Discipline>();

  final _Api _api;
  final _DirectoryCache<Discipline> _cache;

  @override
  Future<PageResult<Discipline>> find(DisciplineQuery query) {
    return _api.run(() async {
      final response = await _api.dio.get(
        '/disciplines',
        queryParameters: _pageQuery(
          search: query.search,
          sortField: query.sortField,
          ascending: query.sortAscending,
          page: query.page,
          size: query.size,
          includeDeleted: query.includeDeleted,
          extra: {
            'country': query.country,
            'yearFrom': query.yearFrom,
            'yearTo': query.yearTo,
          },
        ),
        cancelToken: _api.replaceListToken(),
      );
      return _page(response.data, Discipline.fromJson, query.size);
    });
  }

  @override
  Future<List<Discipline>> all() => _cache.get(_loadAll);

  Future<List<Discipline>> _loadAll() {
    return _api.run(() async {
      final response = await _api.dio.get('/disciplines', queryParameters: {
        'page': 1,
        'size': 500,
        'includeDeleted': true,
        'sort': 'name,asc',
      });
      return _page(response.data, Discipline.fromJson, 500).items;
    });
  }

  @override
  Future<Discipline?> findById(int id) =>
      _optional('/disciplines/$id', Discipline.fromJson);

  @override
  Future<Discipline> create(Discipline discipline) =>
      _save('post', '/disciplines', discipline.toJson());

  @override
  Future<Discipline> update(Discipline discipline) =>
      _save('put', '/disciplines/${discipline.id}', discipline.toJson());

  Future<Discipline> _save(
      String method, String path, Map<String, dynamic> json) {
    json.remove('id');
    json.remove('deletedAt');
    return _api.run(() async {
      final response = method == 'post'
          ? await _api.dio.post(path, data: json)
          : await _api.dio.put(path, data: json);
      _cache.invalidate();
      return Discipline.fromJson(_map(response.data));
    });
  }

  @override
  Future<void> softDelete(int id) =>
      _mutate(() => _api.dio.delete('/disciplines/$id'));

  @override
  Future<void> hardDelete(int id) => _mutate(() =>
      _api.dio.delete('/disciplines/$id', queryParameters: {'hard': true}));

  @override
  Future<void> restore(int id) =>
      _mutate(() => _api.dio.post('/disciplines/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) =>
      _bulk('/disciplines/bulk-delete', ids);

  Future<Discipline?> _optional(
      String path, Discipline Function(Map<String, dynamic>) decode) {
    return _api.run(() async {
      try {
        final response = await _api.dio.get(path);
        return decode(_map(response.data));
      } on DioException catch (error) {
        if (mapDioError(error) is NotFoundException) return null;
        rethrow;
      }
    });
  }

  Future<void> _mutate(Future<Response<dynamic>> Function() action) {
    return _api.run(() async {
      await action();
      _cache.invalidate();
    });
  }

  Future<int> _bulk(String path, List<int> ids) {
    return _api.run(() async {
      final response = await _api.dio.post(path, data: {'ids': ids});
      _cache.invalidate();
      final deleted = _map(response.data)['deleted'];
      return deleted is int ? deleted : int.tryParse('$deleted') ?? 0;
    });
  }
}

class ApiCustomerRepository implements CustomerRepository {
  ApiCustomerRepository(Dio dio) : _api = _Api(dio);

  final _Api _api;

  @override
  Future<PageResult<Customer>> find(CustomerQuery query) {
    return _api.run(() async {
      final response = await _api.dio.get(
        '/customers',
        queryParameters: _pageQuery(
          search: query.search,
          sortField: query.sortField,
          ascending: query.sortAscending,
          page: query.page,
          size: query.size,
          includeDeleted: query.includeDeleted,
          extra: {
            'city': query.city,
            'card': query.cardActive == null
                ? null
                : (query.cardActive! ? '1' : '0'),
            'yearFrom': query.yearFrom,
            'yearTo': query.yearTo,
          },
        ),
        cancelToken: _api.replaceListToken(),
      );
      return _page(response.data, Customer.fromJson, query.size);
    });
  }

  @override
  Future<List<Customer>> all() {
    return _api.run(() async {
      final response = await _api.dio.get('/customers', queryParameters: {
        'page': 1,
        'size': 500,
        'includeDeleted': true,
        'sort': 'fullName,asc',
      });
      return _page(response.data, Customer.fromJson, 500).items;
    });
  }

  @override
  Future<Customer?> findById(int id) =>
      _optional('/customers/$id', Customer.fromJson);

  @override
  Future<bool> isEmailTaken(String email, {int? exceptId}) async {
    final needle = email.trim().toLowerCase();
    final rows = await all();
    return rows.any((item) =>
        item.id != exceptId && item.email.trim().toLowerCase() == needle);
  }

  @override
  Future<Customer> create(Customer customer) =>
      _save('post', '/customers', customer.toJson());

  @override
  Future<Customer> update(Customer customer) =>
      _save('put', '/customers/${customer.id}', customer.toJson());

  Future<Customer> _save(
      String method, String path, Map<String, dynamic> json) {
    json.remove('id');
    json.remove('deletedAt');
    return _api.run(() async {
      final response = method == 'post'
          ? await _api.dio.post(path, data: json)
          : await _api.dio.put(path, data: json);
      return Customer.fromJson(_map(response.data));
    });
  }

  @override
  Future<void> softDelete(int id) =>
      _api.run(() => _api.dio.delete('/customers/$id'));

  @override
  Future<void> hardDelete(int id) => _api.run(
      () => _api.dio.delete('/customers/$id', queryParameters: {'hard': true}));

  @override
  Future<void> restore(int id) =>
      _api.run(() => _api.dio.post('/customers/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) {
    return _api.run(() async {
      final response =
          await _api.dio.post('/customers/bulk-delete', data: {'ids': ids});
      final deleted = _map(response.data)['deleted'];
      return deleted is int ? deleted : int.tryParse('$deleted') ?? 0;
    });
  }

  Future<Customer?> _optional(
      String path, Customer Function(Map<String, dynamic>) decode) {
    return _api.run(() async {
      try {
        final response = await _api.dio.get(path);
        return decode(_map(response.data));
      } on DioException catch (error) {
        if (mapDioError(error) is NotFoundException) return null;
        rethrow;
      }
    });
  }
}
