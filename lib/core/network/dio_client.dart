import 'package:dio/dio.dart';

import '../../config/env_config.dart';
import 'api_exception.dart';

/// 创建配置好的 Dio 实例。
/// - 公共 header：AI-Api-ClientId、AI-Api-Version；登录后加 Authorization: Bearer。
/// - 响应 body.status 非 2xx 时抛 DioException（error 为 ApiException）。
/// - 401/405/409 触发 onUnauthorized（只触发一次）。
Dio createDio({
  required String? Function() readToken,
  required void Function() onUnauthorized,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: EnvConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    headers: {
      'AI-Api-ClientId': EnvConfig.clientId,
      'AI-Api-Version': EnvConfig.apiVersion,
    },
  ));
  if (adapter != null) dio.httpClientAdapter = adapter;

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onResponse: (response, handler) {
      final data = response.data;
      final status = data is Map<String, dynamic> ? data['status'] : null;
      if (status is int && (status < 200 || status > 299)) {
        final apiError = ApiException.fromResponseBody(
          data as Map<String, dynamic>,
        );
        if (apiError.isUnauthorized) onUnauthorized();
        handler.reject(DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: apiError,
        ));
        return;
      }
      handler.next(response);
    },
    onError: (err, handler) {
      // onResponse 里已包装过的直接放行，避免重复触发 onUnauthorized。
      if (err.error is ApiException) {
        handler.next(err);
        return;
      }
      final apiError = ApiException.fromDio(err);
      if (apiError.isUnauthorized) onUnauthorized();
      handler.next(err.copyWith(error: apiError));
    },
  ));
  return dio;
}
