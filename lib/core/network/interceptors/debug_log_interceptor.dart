import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 开发期网络日志拦截器：打印请求/响应摘要与脱敏后的 body。
///
/// 仅应在 kDebugMode 下注册；Authorization、密码、验证码、token 等敏感字段一律打码。
class DebugLogInterceptor extends Interceptor {
  static const _startKey = '__debugLogStart';
  static const _maxBodyLength = 800;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now().millisecondsSinceEpoch;
    final query = options.queryParameters.isEmpty
        ? ''
        : ' ?${options.queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    debugPrint('[HTTP] → ${options.method} ${options.path}$query');
    final data = options.data;
    if (data is Map || data is List) {
      debugPrint('[HTTP]   body: ${_sanitize(data, options.path)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('[HTTP] ← ${response.statusCode} ${response.requestOptions.path}'
        ' (${_elapsed(response.requestOptions)}ms)');
    final data = response.data;
    if (data is Map || data is List || data is String) {
      debugPrint('[HTTP]   body: ${_sanitize(data, response.requestOptions.path)}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[HTTP] ✕ ${err.type} ${err.requestOptions.path}'
        ' (${_elapsed(err.requestOptions)}ms) ${err.message ?? ''}');
    handler.next(err);
  }

  int _elapsed(RequestOptions options) {
    final start = options.extra[_startKey] as int?;
    return start == null ? -1 : DateTime.now().millisecondsSinceEpoch - start;
  }

  /// 递归脱敏后截断；登录接口返回的纯字符串 body 整体打码（token 等）。
  String _sanitize(Object? data, String path) {
    final redacted = data is String && path.contains('/login/')
        ? '***'
        : _sanitizeValue(data).toString();
    return redacted.length > _maxBodyLength
        ? '${redacted.substring(0, _maxBodyLength)}…'
        : redacted;
  }

  Object? _sanitizeValue(Object? value) {
    if (value is Map) {
      return value
          .map((k, v) => MapEntry(k, _isSensitiveKey(k) ? '***' : _sanitizeValue(v)));
    }
    if (value is List) return value.map(_sanitizeValue).toList();
    return value;
  }

  bool _isSensitiveKey(Object? key) {
    final k = key.toString().toLowerCase();
    return k.contains('pass') ||
        k.contains('code') ||
        k.contains('token') ||
        k.contains('secret') ||
        k.contains('authorization') ||
        k.contains('cookie');
  }
}
