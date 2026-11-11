import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ring_shop/core/api_client.dart';
import 'package:ring_shop/core/api_exceptions.dart';
import 'package:ring_shop/models/product.dart';
import 'package:ring_shop/models/product_query.dart';
import 'package:ring_shop/repositories/api_repositories.dart';

void main() {
  Dio scripted(Future<ResponseBody> Function(RequestOptions options) onFetch, {List<Duration>? delays}) {
    final dio = buildDio(retryDelays: delays ?? const []);
    dio.httpClientAdapter = _Script(onFetch);
    return dio;
  }

  ResponseBody jsonBody(Object data, int status) {
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  test('список читает только страницу, которую вернул сервер', () async {
    RequestOptions? seen;
    final dio = scripted((options) async {
      seen = options;
      return jsonBody({
        'items': [
          {
            'id': 5,
            'name': 'Перчатки',
            'sku': 'WN-GL-600',
            'year': 2024,
            'priceRub': 1000,
            'weightGrams': 300,
            'brandId': 3,
            'categoryIds': [1],
            'disciplineIds': [1],
            'stockTotal': 6,
            'stockAvailable': 2,
          },
        ],
        'page': 2,
        'size': 10,
        'total': 24,
      }, 200);
    });
    final page = await ApiProductRepository(dio).find(const ProductQuery(search: 'перч', page: 2));
    expect(page.items.single.sku, 'WN-GL-600');
    expect(page.page, 2);
    expect(page.total, 24);
    expect(seen?.queryParameters['search'], 'перч');
    expect(seen?.queryParameters['page'], 2);
    expect(seen?.path, '/products');
  });

  test('создание разбирает ответ сервера', () async {
    final dio = scripted((options) async {
      final raw = options.data;
      final body = raw is String
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : Map<String, dynamic>.from(raw as Map);
      body['id'] = 40;
      return jsonBody(body, 201);
    });
    final created = await ApiProductRepository(dio).create(
      const Product(
        id: 0,
        name: 'Лапы',
        sku: 'NEW-1',
        year: 2024,
        priceRub: 100,
        weightGrams: 200,
        brandId: 1,
        categoryIds: [1],
        stockTotal: 4,
        stockAvailable: 4,
      ),
    );
    expect(created.id, 40);
    expect(created.sku, 'NEW-1');
  });

  test('ответ 422 становится ошибкой поля', () async {
    final dio = scripted((options) async {
      return jsonBody({
        'message': 'Ошибка валидации',
        'errors': {'sku': 'Такой артикул уже есть'},
      }, 422);
    });
    expect(
      () => ApiProductRepository(dio).create(
        const Product(
          id: 0,
          name: 'Лапы',
          sku: 'EV-GL-10',
          year: 2024,
          priceRub: 100,
          weightGrams: 200,
          brandId: 1,
          categoryIds: [1],
          stockTotal: 4,
          stockAvailable: 4,
        ),
      ),
      throwsA(
        isA<ValidationException>().having((error) => error.errors['sku'], 'sku', 'Такой артикул уже есть'),
      ),
    );
  });

  test('недоступный сервер становится сетевой ошибкой', () async {
    final dio = scripted((options) async {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    });
    expect(
      () => ApiProductRepository(dio).find(const ProductQuery()),
      throwsA(isA<NetworkException>()),
    );
  });

  test('конфликт 409 при продаже без остатка', () async {
    final dio = scripted((options) async {
      return jsonBody({'message': 'Нет свободного остатка: «Leone» продать нельзя.'}, 409);
    });
    expect(
      () => ApiProductRepository(dio).sell(24),
      throwsA(isA<ConflictException>()),
    );
  });

  test('чтение повторяется только при сетевом сбое', () async {
    var calls = 0;
    final dio = scripted(
      (options) async {
        calls += 1;
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
      },
      delays: const [Duration.zero, Duration.zero],
    );
    await expectLater(
      ApiProductRepository(dio).find(const ProductQuery()),
      throwsA(isA<NetworkException>()),
    );
    expect(calls, 3);
  });
}

class _Script implements HttpClientAdapter {
  _Script(this.onFetch);

  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}
