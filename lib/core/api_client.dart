import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../state/auth_notifier.dart';
import 'api_exceptions.dart';
import 'config.dart';

Dio buildDio({
  String? Function()? tokenProvider,
  AuthBinder? binder,
  List<Duration> retryDelays = const [
    Duration(milliseconds: 400),
    Duration(milliseconds: 1200),
  ],
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 90),
      receiveTimeout: const Duration(seconds: 90),
      headers: {
        'Content-Type': 'application/json',
        // Pinggy's free tunnel shows a browser warning unless this header is set.
        'X-Pinggy-No-Screen': '1',
      },
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        final fail = ApiProbe.failOnce;
        if (fail != null) {
          options.queryParameters['__fail'] = fail;
          ApiProbe.failOnce = null;
        }
        final delay = ApiProbe.delayMs;
        if (delay != null) options.queryParameters['__delay'] = delay;
        if (kDebugMode) {
          debugPrint('[API] ${options.method} ${options.uri}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        final status = response.statusCode ?? 0;
        if (kDebugMode) {
          debugPrint(
              '[API] ${response.requestOptions.method} ${response.requestOptions.uri} → $status');
        }
        if (status >= 400) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        if (kDebugMode) {
          debugPrint('[API] сбой ${error.requestOptions.uri}: ${error.type}');
        }
        final options = error.requestOptions;
        final path = options.path;
        final status = error.response?.statusCode;
        final authCall = path.contains('/auth/');
        if (binder != null && status == 401 && !authCall) {
          if (options.extra['authRetried'] == true) {
            await binder.sessionExpired();
            return handler.next(error);
          }
          final refreshed = await binder.refresh();
          if (!refreshed) {
            await binder.sessionExpired();
            return handler.next(error);
          }
          options.extra['authRetried'] = true;
          options.headers['Authorization'] = 'Bearer ${binder.token ?? ''}';
          try {
            final response = await dio.fetch(options);
            return handler.resolve(response);
          } on DioException catch (next) {
            return handler.next(next);
          }
        }
        final attempt = options.extra['attempt'] as int? ?? 0;
        final canRetry = options.method.toUpperCase() == 'GET' &&
            _isNetwork(error) &&
            attempt < retryDelays.length &&
            error.type != DioExceptionType.cancel;
        if (!canRetry) return handler.next(error);
        await Future<void>.delayed(retryDelays[attempt]);
        options.extra['attempt'] = attempt + 1;
        try {
          final response = await dio.fetch(options);
          handler.resolve(response);
        } on DioException catch (next) {
          handler.next(next);
        }
      },
    ),
  );
  return dio;
}

bool _isNetwork(DioException error) {
  return error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError;
}
