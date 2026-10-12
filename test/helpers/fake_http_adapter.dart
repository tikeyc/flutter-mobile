import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 按路径返回预设响应，并记录所有请求（options.data 保留原始 Map）。
class FakeHttpAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, ({int httpStatus, Object? body})> _routes = {};

  void on(String path, {int httpStatus = 200, required Object? body}) {
    _routes[path] = (httpStatus: httpStatus, body: body);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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
