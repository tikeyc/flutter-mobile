import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/core/network/api_exception.dart';
import 'package:intuly/core/network/dio_client.dart';
import 'package:intuly/features/home/data/home_repository.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../fixtures/ins_page_fixtures.dart';

void main() {
  late FakeHttpAdapter adapter;
  late DioHomeRepository repo;

  setUp(() {
    adapter = FakeHttpAdapter();
    repo = DioHomeRepository(
        createDio(readToken: () => null, onUnauthorized: () {}, adapter: adapter));
  });

  RequestOptions lastRequest() => adapter.requests.last;

  group('fetchInsPage', () {
    test('POST /cms/home/insPage 带分页与 venueType 参数，解析 records', () async {
      adapter.on(
        '/cms/home/insPage',
        body: insPageJson(
          records: [insJson()],
          total: 7233,
          current: 2,
          pages: 362,
        ),
      );

      final page = await repo.fetchInsPage(pageNumber: 2);

      expect(lastRequest().method, 'POST');
      expect(lastRequest().path, '/cms/home/insPage');
      expect(lastRequest().data,
          {'pageNumber': 2, 'pageSize': 20, 'venueType': '全部'});
      expect(page.items, hasLength(1));
      expect(page.items.first.bizId, 'ins-1');
      expect(page.hasMore, isTrue);
    });

    test('pageSize 与 venueType 可覆盖', () async {
      adapter.on('/cms/home/insPage', body: insPageJson());

      await repo.fetchInsPage(pageNumber: 3, pageSize: 10, venueType: '景观');

      expect(lastRequest().data,
          {'pageNumber': 3, 'pageSize': 10, 'venueType': '景观'});
    });

    test('只读请求标记 retryable，供重试拦截器识别', () async {
      adapter.on('/cms/home/insPage', body: insPageJson());

      await repo.fetchInsPage(pageNumber: 2);

      expect(lastRequest().extra['retryable'], isTrue);
    });

    test('cancelToken 透传到请求', () async {
      adapter.on('/cms/home/insPage', body: insPageJson(records: [insJson()]));
      final token = CancelToken();

      await repo.fetchInsPage(pageNumber: 2, cancelToken: token);

      expect(lastRequest().cancelToken, same(token));
    });

    test('已取消的 token 抛“请求已取消”', () async {
      final token = CancelToken()..cancel('关闭页面');

      await expectLater(
        repo.fetchInsPage(pageNumber: 2, cancelToken: token),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', '请求已取消')),
      );
    });

    test('current 到达 pages 时 hasMore 为 false', () async {
      adapter.on(
        '/cms/home/insPage',
        body: insPageJson(records: [insJson()], current: 362, pages: 362),
      );

      final page = await repo.fetchInsPage(pageNumber: 362);

      expect(page.hasMore, isFalse);
    });

    test('响应缺 current/pages 时按本页条数判断 hasMore', () async {
      adapter.on('/cms/home/insPage', body: {
        'status': 200,
        'data': {
          'records': [insJson(), modelJson()],
        },
      });

      final page = await repo.fetchInsPage(pageNumber: 2, pageSize: 2);

      expect(page.hasMore, isTrue);
    });

    test('单项数据损坏时跳过而不拖垮整页', () async {
      final bad = insJson()..['type'] = 99;
      adapter.on(
        '/cms/home/insPage',
        body: insPageJson(records: [bad, modelJson()], current: 2, pages: 5),
      );

      final page = await repo.fetchInsPage(pageNumber: 2);

      expect(page.items, hasLength(1));
      expect(page.items.first.bizId, 'model-1');
    });

    test('records 非列表时抛 ApiException', () async {
      adapter.on('/cms/home/insPage', body: {
        'status': 200,
        'data': {'records': null},
      });

      await expectLater(
          repo.fetchInsPage(pageNumber: 2), throwsA(isA<ApiException>()));
    });

    test('data 非对象时抛 ApiException', () async {
      adapter.on('/cms/home/insPage', body: {'status': 200, 'data': null});

      await expectLater(
          repo.fetchInsPage(pageNumber: 2), throwsA(isA<ApiException>()));
    });

    test('status 非 2xx 抛 ApiException', () async {
      adapter.on('/cms/home/insPage', body: {'status': 500, 'message': '服务异常'});

      await expectLater(
          repo.fetchInsPage(pageNumber: 2), throwsA(isA<ApiException>()));
    });
  });
}
