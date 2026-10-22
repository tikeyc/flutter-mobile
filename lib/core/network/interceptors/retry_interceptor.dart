import 'package:dio/dio.dart';

/// 自动重试拦截器。
///
/// 仅对幂等请求（GET/HEAD/OPTIONS/PUT/DELETE）或显式
/// `options.extra[retryableExtraKey] = true` 的请求，在连接超时、发送超时、
/// 接收超时、连接错误时按退避间隔重试；取消、业务错误、证书错误一律不重试。
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.retries = 2,
    this.baseDelay = const Duration(milliseconds: 300),
  });

  final Dio _dio;
  final int retries;
  final Duration baseDelay;

  /// 在 Options.extra 里置 true 可让非幂等请求（如只读 POST）参与重试。
  static const String retryableExtraKey = 'retryable';
  static const String _attemptExtraKey = 'retryAttempt';

  static const _idempotentMethods = {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'};

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptExtraKey] as int?) ?? 0;
    if (attempt >= retries || !_shouldRetry(err)) {
      return handler.next(err);
    }
    options.extra[_attemptExtraKey] = attempt + 1;
    await Future<void>.delayed(baseDelay * (attempt + 1));
    try {
      final response = await _dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _shouldRetry(DioException err) {
    final retryableType = switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      _ => false,
    };
    if (!retryableType) return false;
    final options = err.requestOptions;
    if (options.extra[retryableExtraKey] == true) return true;
    return _idempotentMethods.contains(options.method.toUpperCase());
  }
}
