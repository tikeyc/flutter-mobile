import 'package:dio/dio.dart';

import '../api_exception.dart';

/// 业务拆包拦截器：响应 body.status 非 2xx 视为业务失败，
/// 转成 DioException（error 为 ApiException）抛出；401/405/409 触发 onUnauthorized。
class EnvelopeInterceptor extends Interceptor {
  EnvelopeInterceptor({required this.onUnauthorized});

  final void Function() onUnauthorized;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is Map && data['status'] is int) {
      final status = data['status'] as int;
      if (status < 200 || status > 299) {
        final apiError = ApiException.fromResponseBody(data.cast<String, dynamic>());
        if (apiError.isUnauthorized) onUnauthorized();
        handler.reject(DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: apiError,
        ));
        return;
      }
    }
    handler.next(response);
  }
}
