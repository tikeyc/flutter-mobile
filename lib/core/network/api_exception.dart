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

  /// 从 DioException 构造：优先 body.status，其次 HTTP 状态码，最后按错误类型给文案。
  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['status'] is int) {
      return ApiException.fromResponseBody(data.cast<String, dynamic>());
    }
    final httpStatus = e.response?.statusCode;
    if (httpStatus != null) {
      return ApiException(status: httpStatus, message: _messageForHttpStatus(httpStatus));
    }
    return ApiException(status: null, message: _messageForType(e.type));
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

  static String _messageForHttpStatus(int status) {
    switch (status) {
      case 400:
        return '请求参数错误';
      case 401:
      case 405:
      case 409:
        return '登录已过期，请重新登录';
      case 403:
        return '账号或密码错误';
      case 404:
        return '资源不存在';
      case 500:
        return '服务器内部错误';
      default:
        return '请求失败($status)，请稍后重试';
    }
  }

  static String _messageForType(DioExceptionType type) {
    switch (type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络后重试';
      case DioExceptionType.sendTimeout:
        return '发送超时，请稍后重试';
      case DioExceptionType.receiveTimeout:
        return '响应超时，服务器繁忙，请稍后重试';
      case DioExceptionType.badCertificate:
        return '安全证书校验失败';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.transformTimeout:
        return '响应数据处理超时，请稍后重试';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return '网络错误，请稍后重试';
    }
  }

  @override
  String toString() => 'ApiException(status: $status, message: $message)';
}
