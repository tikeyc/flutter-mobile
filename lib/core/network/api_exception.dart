import 'package:dio/dio.dart';

/// 业务层 API 异常。status 优先取响应 body.status，回退取 HTTP 状态码。
class ApiException implements Exception {
  final int? status;
  final String message;

  const ApiException({required this.status, required this.message});

  /// 从响应 body（{status, message, data}）构造。
  factory ApiException.fromResponseBody(Map<String, dynamic> body) {
    final status = body['status'] as int?;
    final message = body['message'];
    return ApiException(
      status: status,
      message: message is String && message.isNotEmpty
          ? message
          : _defaultMessage(status),
    );
  }

  /// 从 DioException 构造：优先读 response.data，回退读 HTTP 状态码。
  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['status'] is int) {
      return ApiException.fromResponseBody(data);
    }
    final status = e.response?.statusCode;
    return ApiException(status: status, message: _defaultMessage(status));
  }

  /// 401/405/409：登录失效，需要清除会话。
  bool get isUnauthorized => status == 401 || status == 405 || status == 409;

  /// 403：账号或密码错误。
  bool get isWrongCredentials => status == 403;

  /// 301 封禁 / 302 冻结 / 303 违规。
  bool get isAccountDisabled => status == 301 || status == 302 || status == 303;

  static String _defaultMessage(int? status) {
    switch (status) {
      case 403:
        return '账号或密码错误';
      case 401:
      case 405:
      case 409:
        return '登录已过期，请重新登录';
      default:
        return '网络错误，请稍后重试';
    }
  }

  @override
  String toString() => 'ApiException(status: $status, message: $message)';
}
