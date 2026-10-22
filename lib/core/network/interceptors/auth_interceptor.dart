import 'package:dio/dio.dart';

/// 认证拦截器：登录后为每个请求注入 `Authorization: Bearer <token>`。
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.readToken});

  final String? Function() readToken;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
