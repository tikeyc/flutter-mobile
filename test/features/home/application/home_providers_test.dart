import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/core/network/api_exception.dart';
import 'package:intuly/features/home/application/home_providers.dart';
import 'package:intuly/features/home/data/home_repository.dart';
import 'package:intuly/features/home/data/models/feed_item.dart';

import '../fixtures/ins_page_fixtures.dart';
/// 直接替换实现，避免走网络层。
class FakeHomeRepository implements HomeRepository {
  List<List<Map<String, dynamic>>> pages = [];

  /// 与 pages 一一对应；缺省或超出时按 true 处理。
  List<bool> hasMoreFlags = [];
  int calls = 0;
  Object? error;
  final List<int> pageNumbers = [];

  @override
  Future<InsPage> fetchInsPage({
    required int pageNumber,
    int pageSize = 20,
    String venueType = '全部',
  }) async {
    calls++;
    pageNumbers.add(pageNumber);
    if (error != null) throw error!;
    // 调用次数超出预设页数时复用最后一页。
    final index = calls <= pages.length ? calls - 1 : pages.length - 1;
    final page = pages.isEmpty ? <Map<String, dynamic>>[] : pages[index];
    final hasMore = hasMoreFlags.isEmpty
        ? true
        : hasMoreFlags[calls <= hasMoreFlags.length ? calls - 1 : hasMoreFlags.length - 1];
    return InsPage(
      items: page.map((e) => FeedItem.fromJson(e)).toList(),
      hasMore: hasMore,
    );
  }
}

void main() {
  late FakeHomeRepository repo;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
        overrides: [homeRepoProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    repo = FakeHomeRepository();
  });

  test('build 时自动加载首页数据（pageNumber=2）', () async {
    repo.pages = [
      [insJson(), modelJson()]
    ];
    final c = makeContainer();
    final state = await c.listenForLoad();
    expect(state.items, hasLength(2));
    expect(repo.pageNumbers, [2]);
    expect(state.loading, isFalse);
    expect(state.error, isNull);
    expect(state.hasMore, isTrue);
  });

  test('首次加载失败进入 error 状态，retry 成功恢复', () async {
    repo.error = const FormatException('x');
    final c = makeContainer();
    final state1 = await c.listenForLoad();
    expect(state1.items, isEmpty);
    expect(state1.error, isNotNull);
    expect(state1.loading, isFalse);

    repo.error = null;
    repo.pages = [
      [designJson()]
    ];
    await c.read(homeFeedProvider.notifier).retry();
    final state2 = c.read(homeFeedProvider);
    expect(state2.error, isNull);
    expect(state2.items, hasLength(1));
  });

  test('loadMore 合并数据并按 bizId 去重', () async {
    repo.pages = [
      [insJson(), modelJson()],
      [
        insJson(), // bizId 重复
        designJson(),
      ],
    ];
    final c = makeContainer();
    await c.listenForLoad();

    await c.read(homeFeedProvider.notifier).loadMore();

    final state = c.read(homeFeedProvider);
    expect(state.items.map((e) => e.bizId), ['ins-1', 'model-1', 'design-1']);
    expect(repo.pageNumbers, [2, 3]);
    expect(state.loadingMore, isFalse);
  });

  test('hasMore 为 false 后再上拉不发请求', () async {
    repo.pages = [
      [insJson()],
      [designJson()],
    ];
    repo.hasMoreFlags = [false];
    final c = makeContainer();
    final state1 = await c.listenForLoad();
    expect(state1.hasMore, isFalse);

    await c.read(homeFeedProvider.notifier).loadMore();

    expect(repo.calls, 1);
    expect(c.read(homeFeedProvider).items, hasLength(1));
  });

  test('首次已加载时再 loadMore，重复触发不会并发请求', () async {
    repo.pages = [
      [insJson()],
      [designJson()],
    ];
    final c = makeContainer();
    await c.listenForLoad();

    final f1 = c.read(homeFeedProvider.notifier).loadMore();
    final f2 = c.read(homeFeedProvider.notifier).loadMore();
    await Future.wait([f1, f2]);

    expect(repo.calls, 2);
  });

  test('loadMore 成功后短时间内重复触发被节流', () async {
    repo.pages = [
      [insJson()],
      [designJson()],
    ];
    final c = makeContainer();
    await c.listenForLoad();

    await c.read(homeFeedProvider.notifier).loadMore();
    // 紧接着再次触发（甩动场景），1 秒内被节流，不再发请求。
    await c.read(homeFeedProvider.notifier).loadMore();

    expect(repo.calls, 2);
    expect(
      c.read(homeFeedProvider).items.map((e) => e.bizId),
      ['ins-1', 'design-1'],
    );
  });

  test('loadMore 失败保留已有数据且错误不影响主列表', () async {
    repo.pages = [
      [insJson()]
    ];
    final c = makeContainer();
    await c.listenForLoad();

    repo.error = const FormatException('y');
    await c.read(homeFeedProvider.notifier).loadMore();

    final state = c.read(homeFeedProvider);
    expect(state.items, hasLength(1));
    expect(state.loadingMore, isFalse);
    // 下次上拉恢复后可继续加载
    repo.error = null;
    repo.pages.add([designJson()]);
    await c.read(homeFeedProvider.notifier).loadMore();
    expect(c.read(homeFeedProvider).items, hasLength(2));
  });

  test('加载失败错误信息来自 ApiException', () async {
    repo.error = const ApiException(status: 500, message: '获取首页数据失败，请重试');
    final c = makeContainer();
    final state = await c.listenForLoad();
    expect(state.error, '获取首页数据失败，请重试');
  });
}

extension on ProviderContainer {
  /// 等待 build 触发的首次加载完成。
  Future<HomeFeedState> listenForLoad() async {
    listen(homeFeedProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return read(homeFeedProvider);
  }
}
