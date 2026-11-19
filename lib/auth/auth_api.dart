import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import 'auth_user.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthResult> login(String username, String password) {
    return _send('/auth/login', {'username': username, 'password': password});
  }

  Future<AuthResult> register({
    required String username,
    required String password,
    required String fullName,
  }) {
    return _send('/auth/register', {
      'username': username,
      'password': password,
      'fullName': fullName,
    });
  }

  Future<AuthResult> refresh(String refreshToken) {
    return _send('/auth/refresh', {'refreshToken': refreshToken});
  }

  Future<AppUser> me() {
    return guard(() async {
      final response = await _dio.get('/auth/me');
      final data = response.data;
      if (data is Map<String, dynamic>) return AppUser.fromJson(data);
      if (data is Map) return AppUser.fromJson(Map<String, dynamic>.from(data));
      throw const ServerException('Пустой ответ профиля');
    });
  }

  Future<AuthResult> _send(String path, Map<String, dynamic> body) {
    return guard(() async {
      final response = await _dio.post(path, data: body);
      final data = response.data;
      if (data is Map<String, dynamic>) return AuthResult.fromJson(data);
      if (data is Map) {
        return AuthResult.fromJson(Map<String, dynamic>.from(data));
      }
      throw const ServerException('Пустой ответ входа');
    });
  }
}

class DeskApi {
  DeskApi(this._dio);

  final Dio _dio;

  Future<List<ShopOrder>> orders() => _list('/orders', ShopOrder.fromJson);

  Future<ShopOrder> extendOrder(int id) =>
      _one('/orders/$id/extend', ShopOrder.fromJson);

  Future<List<ShopSale>> sales() => _list('/sales', ShopSale.fromJson);

  Future<ShopSale> openSale({required int productId, required int customerId}) {
    return _one('/sales', ShopSale.fromJson, body: {
      'productId': productId,
      'customerId': customerId,
    });
  }

  Future<ShopSale> closeSale(int id) =>
      _one('/sales/$id/close', ShopSale.fromJson);

  Future<List<AccountUser>> users() => _list('/users', AccountUser.fromJson);

  Future<AccountUser> setRole(int id, String role) {
    return guard(() async {
      final response = await _dio.put('/users/$id', data: {'role': role});
      return AccountUser.fromJson(_map(response.data));
    });
  }

  Future<ShopStats> stats() {
    return guard(() async {
      final response = await _dio.get('/stats');
      return ShopStats.fromJson(_map(response.data));
    });
  }

  Future<List<T>> _list<T>(
      String path, T Function(Map<String, dynamic>) decode) {
    return guard(() async {
      final response = await _dio.get(path);
      final data = response.data;
      final items = data is Map ? data['items'] : data;
      if (items is! List) return [];
      return [
        for (final item in items)
          if (item is Map) decode(Map<String, dynamic>.from(item)),
      ];
    });
  }

  Future<T> _one<T>(String path, T Function(Map<String, dynamic>) decode,
      {Map<String, dynamic>? body}) {
    return guard(() async {
      final response = body == null
          ? await _dio.post(path)
          : await _dio.post(path, data: body);
      return decode(_map(response.data));
    });
  }
}

Map<String, dynamic> _map(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return {};
}

class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.productName,
    required this.dueAt,
    required this.status,
  });

  final int id;
  final String productName;
  final DateTime dueAt;
  final String status;

  factory ShopOrder.fromJson(Map<String, dynamic> json) {
    return ShopOrder(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      productName: '${json['productName'] ?? ''}',
      dueAt: DateTime.tryParse('${json['dueAt']}')?.toLocal() ?? DateTime.now(),
      status: '${json['status'] ?? ''}',
    );
  }
}

class ShopSale {
  const ShopSale({
    required this.id,
    required this.productName,
    required this.customerName,
    required this.status,
  });

  final int id;
  final String productName;
  final String customerName;
  final String status;

  bool get isOpen => status == 'open';

  factory ShopSale.fromJson(Map<String, dynamic> json) {
    return ShopSale(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      productName: '${json['productName'] ?? ''}',
      customerName: '${json['customerName'] ?? ''}',
      status: '${json['status'] ?? ''}',
    );
  }
}

class AccountUser {
  const AccountUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
  });

  final int id;
  final String username;
  final String fullName;
  final String role;

  factory AccountUser.fromJson(Map<String, dynamic> json) {
    return AccountUser(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      username: '${json['username'] ?? ''}',
      fullName: '${json['fullName'] ?? ''}',
      role: '${json['role'] ?? ''}',
    );
  }
}

class ShopStats {
  const ShopStats({
    required this.products,
    required this.brands,
    required this.customers,
    required this.users,
    required this.openSales,
  });

  final int products;
  final int brands;
  final int customers;
  final int users;
  final int openSales;

  factory ShopStats.fromJson(Map<String, dynamic> json) {
    int n(String key) =>
        json[key] is int ? json[key] as int : int.tryParse('${json[key]}') ?? 0;
    return ShopStats(
      products: n('products'),
      brands: n('brands'),
      customers: n('customers'),
      users: n('users'),
      openSales: n('openSales'),
    );
  }
}
