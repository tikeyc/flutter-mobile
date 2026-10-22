import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 按路径返回预设响应，并记录所有请求（options.data 保留原始 Map）。
class FakeHttpAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, ({int httpStatus, Object? body})> _routes = {};
  final Map<String, ({int remaining, DioExceptionType type})> _failures = {};

  void on(String path, {int httpStatus = 200, required Object? body}) {
    _routes[path] = (httpStatus: httpStatus, body: body);
  }

  /// 对 [path] 的下一次请求以指定错误类型失败；可重复调用累加失败次数。
  void failNext(String path,
      {DioExceptionType type = DioExceptionType.connectionError}) {
    final current = _failures[path];
    _failures[path] = (remaining: (current?.remaining ?? 0) + 1, type: type);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final failure = _failures[options.path];
    if (failure != null) {
      if (failure.remaining <= 1) {
        _failures.remove(options.path);
      } else {
        _failures[options.path] =
            (remaining: failure.remaining - 1, type: failure.type);
      }
      throw DioException(requestOptions: options, type: failure.type);
    }
    final route = _routes[options.path];
    if (route == null) {
      throw StateError('FakeHttpAdapter: 未注册路径 ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode(route.body),
      route.httpStatus,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
