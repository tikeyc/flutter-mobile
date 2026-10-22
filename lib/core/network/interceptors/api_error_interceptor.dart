import 'package:dio/dio.dart';

import '../api_exception.dart';

/// 错误映射拦截器：把底层 DioException 统一包装成 ApiException；
/// 401/405/409 触发 onUnauthorized。
class ApiErrorInterceptor extends Interceptor {
  ApiErrorInterceptor({required this.onUnauthorized});

  final void Function() onUnauthorized;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // EnvelopeInterceptor 里已包装过的直接放行，避免重复触发 onUnauthorized。
    if (err.error is ApiException) {
      handler.next(err);
      return;
    }
    final apiError = ApiException.fromDio(err);
    if (apiError.isUnauthorized) onUnauthorized();
    handler.next(err.copyWith(error: apiError));
  }
}
