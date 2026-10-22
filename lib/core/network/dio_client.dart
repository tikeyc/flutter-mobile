import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/env_config.dart';
import 'interceptors/api_error_interceptor.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/debug_log_interceptor.dart';
import 'interceptors/envelope_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

/// 创建配置好的 Dio 实例。
/// - 公共 header：AI-Api-ClientId、AI-Api-Version；登录后加 Authorization: Bearer。
/// - 响应 body.status 非 2xx 时抛 DioException（error 为 ApiException）。
/// - 401/405/409 触发 onUnauthorized（只触发一次）。
/// - 幂等请求或 extra['retryable'] = true 的请求遇网络错误自动重试 2 次。
/// - kDebugMode 下输出脱敏后的请求日志。
Dio createDio({
  required String? Function() readToken,
  required void Function() onUnauthorized,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: EnvConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    persistentConnection: !kIsWeb,
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    headers: {
      'AI-Api-ClientId': EnvConfig.clientId,
      'AI-Api-Version': EnvConfig.apiVersion,
    },
  ));
  if (adapter != null) dio.httpClientAdapter = adapter;

  dio.interceptors.addAll([
    AuthInterceptor(readToken: readToken),
    EnvelopeInterceptor(onUnauthorized: onUnauthorized),
    ApiErrorInterceptor(onUnauthorized: onUnauthorized),
    RetryInterceptor(dio),
    if (kDebugMode) DebugLogInterceptor(),
  ]);
  return dio;
}
