import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/core/network/api_exception.dart';
import 'package:intuly/core/network/dio_client.dart';
import 'package:intuly/features/home/data/home_repository.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../fixtures/hotlist_fixtures.dart';

void main() {
  late FakeHttpAdapter adapter;
  late DioHomeRepository repo;

  setUp(() {
    adapter = FakeHttpAdapter();
    repo = DioHomeRepository(
        createDio(readToken: () => null, onUnauthorized: () {}, adapter: adapter));
  });

  RequestOptions lastRequest() => adapter.requests.last;

  group('fetchHotList', () {
    test('首次请求带 isOperational=true，返回解析后的列表', () async {
      adapter.on('/cms/home/hotList', body: {
        'status': 200,
        'message': '操作成功',
        'data': [insJson()],
      });

      final items = await repo.fetchHotList(first: true);

      expect(lastRequest().method, 'GET');
      expect(lastRequest().queryParameters, {'isOperational': true});
      expect(items, hasLength(1));
      expect(items.first.bizId, 'ins-1');
    });

    test('后续请求不带 isOperational', () async {
      adapter.on('/cms/home/hotList', body: {'status': 200, 'data': []});

      await repo.fetchHotList(first: false);

      expect(lastRequest().queryParameters, isEmpty);
    });

    test('单项数据损坏时跳过而不拖垮整页', () async {
      final bad = insJson()..['type'] = 99;
      adapter.on('/cms/home/hotList', body: {
        'status': 200,
        'data': [bad, modelJson()],
      });

      final items = await repo.fetchHotList(first: true);

      expect(items, hasLength(1));
      expect(items.first.bizId, 'model-1');
    });

    test('data 非列表时抛 ApiException', () async {
      adapter.on('/cms/home/hotList', body: {'status': 200, 'data': null});

      await expectLater(repo.fetchHotList(first: true), throwsA(isA<ApiException>()));
    });

    test('status 非 2xx 抛 ApiException', () async {
      adapter.on('/cms/home/hotList', body: {'status': 500, 'message': '服务异常'});

      await expectLater(repo.fetchHotList(first: true), throwsA(isA<ApiException>()));
    });
  });
}
