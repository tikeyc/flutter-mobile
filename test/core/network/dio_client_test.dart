import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/core/network/api_exception.dart';
import 'package:intuly/core/network/dio_client.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late Dio dio;
  String? token;
  var unauthorizedCalls = 0;

  setUp(() {
    adapter = FakeHttpAdapter();
    token = null;
    unauthorizedCalls = 0;
    dio = createDio(
      readToken: () => token,
      onUnauthorized: () => unauthorizedCalls++,
      adapter: adapter,
    );
  });

  Matcher apiError(int status) => isA<DioException>().having(
      (e) => e.error, 'error', isA<ApiException>().having((a) => a.status, 'status', status));

  test('三种超时按教程典型值配置', () {
    expect(dio.options.connectTimeout, const Duration(seconds: 10));
    expect(dio.options.sendTimeout, const Duration(seconds: 15));
    expect(dio.options.receiveTimeout, const Duration(seconds: 15));
  });

  group('重试', () {
    test('retryable POST 遇网络错误自动重试并成功', () async {
      adapter.on('/feed', body: {'status': 200, 'data': 'ok'});
      adapter.failNext('/feed');
      await dio.post<Object?>('/feed',
          options: Options(extra: {'retryable': true}));
      expect(adapter.requests, hasLength(2));
    });

    test('普通 POST 网络错误不重试', () async {
      adapter.on('/feed', body: {'status': 200, 'data': 'ok'});
      adapter.failNext('/feed');
      await expectLater(dio.post<Object?>('/feed'), throwsA(isA<DioException>()));
      expect(adapter.requests, hasLength(1));
    });

    test('GET 默认重试', () async {
      adapter.on('/feed', body: {'status': 200, 'data': 'ok'});
      adapter.failNext('/feed');
      await dio.get<Object?>('/feed');
      expect(adapter.requests, hasLength(2));
    });

    test('HTTP 4xx 不重试', () async {
      adapter.on('/feed', httpStatus: 400, body: {'message': 'bad'});
      await expectLater(dio.get<Object?>('/feed'), throwsA(isA<DioException>()));
      expect(adapter.requests, hasLength(1));
    });

    test('重试上限 2 次，之后抛出错误', () async {
      adapter.on('/feed', body: {'status': 200, 'data': 'ok'});
      adapter.failNext('/feed');
      adapter.failNext('/feed');
      adapter.failNext('/feed');
      await expectLater(
        dio.get<Object?>('/feed'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, hasLength(3));
    });

    test('重试成功的请求最终结果正确', () async {
      adapter.on('/feed', body: {'status': 200, 'data': 'ok'});
      adapter.failNext('/feed');
      final res = await dio.post<Map<String, dynamic>>('/feed',
          options: Options(extra: {'retryable': true}));
      expect(res.data!['data'], 'ok');
    });
  });

  test('带公共 header，未登录时不带 Authorization', () async {
    adapter.on('/ping', body: {'status': 200, 'data': 'ok'});
    await dio.post<Object?>('/ping');
    final req = adapter.requests.single;
    expect(req.headers['AI-Api-ClientId'], '101409740478767510');
    expect(req.headers['AI-Api-Version'], 'v1.0.0');
    expect(req.headers.containsKey('Authorization'), isFalse);
    expect(req.baseUrl, 'https://www.intuly.com/api');
  });

  test('登录后带 Bearer token', () async {
    token = 'tk-123';
    adapter.on('/ping', body: {'status': 200, 'data': 'ok'});
    await dio.post<Object?>('/ping');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer tk-123');
  });

  test('body.status 201 视为成功', () async {
    adapter.on('/ping', body: {'status': 201, 'data': 'x'});
    final res = await dio.post<Map<String, dynamic>>('/ping');
    expect(res.data!['status'], 201);
  });

  test('body.status 403 抛 ApiException，不触发退出', () async {
    adapter.on('/ping', body: {'status': 403, 'message': '账号或密码错误'});
    await expectLater(dio.post<Object?>('/ping'), throwsA(apiError(403)));
    expect(unauthorizedCalls, 0);
  });

  for (final s in [401, 405, 409]) {
    test('body.status $s 触发且只触发一次 onUnauthorized', () async {
      adapter.on('/ping', body: {'status': s});
      await expectLater(dio.post<Object?>('/ping'), throwsA(apiError(s)));
      expect(unauthorizedCalls, 1);
    });
  }

  test('HTTP 500 无 body.status 时回退到 HTTP 状态码', () async {
    adapter.on('/ping', httpStatus: 500, body: 'Server Error');
    await expectLater(dio.post<Object?>('/ping'), throwsA(apiError(500)));
  });

  test('ApiException 分类', () {
    expect(const ApiException(status: 302, message: '').isAccountDisabled, isTrue);
    expect(const ApiException(status: 403, message: '').isWrongCredentials, isTrue);
    expect(const ApiException(status: 403, message: '').isAccountDisabled, isFalse);
  });
}
