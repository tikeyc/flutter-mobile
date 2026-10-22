import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/core/network/api_exception.dart';

void main() {
  RequestOptions requestOptions() => RequestOptions(path: '/x');

  DioException dioError(
    DioExceptionType type, {
    int? httpStatus,
    Object? body,
  }) {
    final options = requestOptions();
    return DioException(
      requestOptions: options,
      type: type,
      response: httpStatus == null
          ? null
          : Response(statusCode: httpStatus, requestOptions: options, data: body),
    );
  }

  group('fromDio 网络错误类型映射', () {
    test('连接超时', () {
      final e = ApiException.fromDio(dioError(DioExceptionType.connectionTimeout));
      expect(e.status, isNull);
      expect(e.message, '连接超时，请检查网络后重试');
    });

    test('发送超时', () {
      final e = ApiException.fromDio(dioError(DioExceptionType.sendTimeout));
      expect(e.message, '发送超时，请稍后重试');
    });

    test('接收超时', () {
      final e = ApiException.fromDio(dioError(DioExceptionType.receiveTimeout));
      expect(e.message, '响应超时，服务器繁忙，请稍后重试');
    });

    test('连接错误', () {
      final e = ApiException.fromDio(dioError(DioExceptionType.connectionError));
      expect(e.message, '网络连接失败，请检查网络');
    });

    test('请求取消', () {
      final e = ApiException.fromDio(dioError(DioExceptionType.cancel));
      expect(e.message, '请求已取消');
    });

    test('证书校验失败', () {
      final e = ApiException.fromDio(dioError(DioExceptionType.badCertificate));
      expect(e.message, '安全证书校验失败');
    });

    test('未知错误', () {
      final e = ApiException.fromDio(dioError(DioExceptionType.unknown));
      expect(e.message, '网络错误，请稍后重试');
    });
  });

  group('fromDio HTTP 状态码映射', () {
    test('400 请求参数错误', () {
      final e = ApiException.fromDio(
          dioError(DioExceptionType.badResponse, httpStatus: 400, body: 'bad request'));
      expect(e.status, 400);
      expect(e.message, '请求参数错误');
    });

    test('401 登录已过期', () {
      final e = ApiException.fromDio(
          dioError(DioExceptionType.badResponse, httpStatus: 401));
      expect(e.status, 401);
      expect(e.message, '登录已过期，请重新登录');
      expect(e.isUnauthorized, isTrue);
    });

    test('403 账号或密码错误', () {
      final e = ApiException.fromDio(
          dioError(DioExceptionType.badResponse, httpStatus: 403));
      expect(e.message, '账号或密码错误');
      expect(e.isWrongCredentials, isTrue);
    });

    test('404 资源不存在', () {
      final e = ApiException.fromDio(
          dioError(DioExceptionType.badResponse, httpStatus: 404));
      expect(e.message, '资源不存在');
    });

    test('500 服务器内部错误', () {
      final e = ApiException.fromDio(
          dioError(DioExceptionType.badResponse, httpStatus: 500));
      expect(e.message, '服务器内部错误');
    });

    test('其他状态码给通用提示', () {
      final e = ApiException.fromDio(
          dioError(DioExceptionType.badResponse, httpStatus: 502));
      expect(e.message, '请求失败(502)，请稍后重试');
    });
  });

  group('fromDio 业务码优先', () {
    test('body.status 存在时以业务体为准', () {
      final e = ApiException.fromDio(dioError(
        DioExceptionType.badResponse,
        httpStatus: 200,
        body: {'status': 301, 'message': '账号已被封禁'},
      ));
      expect(e.status, 301);
      expect(e.message, '账号已被封禁');
      expect(e.isAccountDisabled, isTrue);
    });
  });
}
