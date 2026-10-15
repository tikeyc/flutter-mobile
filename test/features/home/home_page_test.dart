import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/auth/application/auth_providers.dart';
import 'package:intuly/features/home/application/home_providers.dart';
import 'package:intuly/features/home/data/home_repository.dart';
import 'package:intuly/features/home/data/models/feed_item.dart';
import 'package:intuly/features/home/presentation/widgets/feed_card.dart';
import 'package:intuly/features/home/presentation/widgets/home_bottom_nav.dart';
import 'package:intuly/router/app_router.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/in_memory_session_storage.dart';
import 'fixtures/ins_page_fixtures.dart';

/// 顺序返回预设页，避免走网络层。
class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository(this.pages);

  final List<List<Map<String, dynamic>>> pages;
  int calls = 0;

  @override
  Future<InsPage> fetchInsPage({
    required int pageNumber,
    int pageSize = 20,
    String venueType = '全部',
  }) async {
    final page = pages[calls < pages.length ? calls : pages.length - 1];
    calls++;
    return InsPage(
      items: page.map((e) => FeedItem.fromJson(e)).toList(),
      hasMore: true,
    );
  }
}

/// 经真实 appRouterProvider（StatefulShellRoute）驱动首页，游客身份。
Future<void> pumpHomeApp(WidgetTester tester, FakeHomeRepository repo) async {
  final container = ProviderContainer(
    overrides: [
      initialSessionProvider.overrideWithValue(null),
      sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
      authRepoProvider.overrideWithValue(FakeAuthRepository()),
      homeRepoProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: container.read(appRouterProvider)),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapBottomTab(WidgetTester tester, String label) {
  return tester.tap(
    find.descendant(
      of: find.byType(HomeBottomNav),
      matching: find.text(label),
    ),
  );
}

void main() {
  testWidgets('首页以瀑布流渲染卡片，上拉触发加载更多', (tester) async {
    final repo = FakeHomeRepository([
      [insJson(), modelJson()],
      [designJson(), goodsJson()],
    ]);
    await pumpHomeApp(tester, repo);

    expect(find.byType(SliverMasonryGrid), findsOneWidget);
    expect(find.byType(FeedCard), findsNWidgets(2));

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -2000),
      1000,
    );
    await tester.pumpAndSettle();

    // 甩动期间每帧都会触发上拉，但成功加载后 1 秒内节流：整个甩动只发一次请求。
    expect(repo.calls, 2);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(FeedCard).first));
    expect(container.read(homeFeedProvider).items, hasLength(4));

    // 滚到底部后，新加载的两张卡内容已上屏。
    expect(find.text('餐厅全案设计项目'), findsOneWidget);
    expect(find.text('商品名称商品名称'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击左上角汉堡按钮滑出抽屉，点击菜单项后关闭', (tester) async {
    final repo = FakeHomeRepository([
      [insJson(), modelJson()],
    ]);
    await pumpHomeApp(tester, repo);

    // 初始时抽屉不可见。
    expect(find.text('我的主页'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // 抽屉滑出，占位菜单项全部可见。
    expect(find.text('我的主页'), findsOneWidget);
    expect(find.text('消息通知'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);

    // 点击菜单项后抽屉滑回关闭。
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('底部导航切换显示模型广场/需求大厅/好物商城占位页', (tester) async {
    final repo = FakeHomeRepository([
      [insJson(), modelJson()],
    ]);
    await pumpHomeApp(tester, repo);

    // 外壳用 IndexedStack 承载四个 tab 页，finder 只看到当前选中页。
    expect(find.byType(IndexedStack), findsOneWidget);
    expect(find.text('模型广场建设中，敬请期待'), findsNothing);

    await tapBottomTab(tester, '模型广场');
    await tester.pumpAndSettle();
    expect(find.text('模型广场建设中，敬请期待'), findsOneWidget);

    await tapBottomTab(tester, '需求大厅');
    await tester.pumpAndSettle();
    expect(find.text('需求大厅建设中，敬请期待'), findsOneWidget);
    expect(find.text('模型广场建设中，敬请期待'), findsNothing);

    await tapBottomTab(tester, '好物商城');
    await tester.pumpAndSettle();
    expect(find.text('好物商城建设中，敬请期待'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换底部 tab 再切回，灵感社区滚动位置保持', (tester) async {
    final repo = FakeHomeRepository([
      [insJson(), modelJson()],
      [designJson(), goodsJson()],
    ]);
    await pumpHomeApp(tester, repo);

    // 滚动瀑布流，让第二页卡片上屏。
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -2000),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('餐厅全案设计项目'), findsOneWidget);

    // 切到模型广场再切回灵感社区。
    await tapBottomTab(tester, '模型广场');
    await tester.pumpAndSettle();
    await tapBottomTab(tester, '灵感社区');
    await tester.pumpAndSettle();

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
    // 页面未被重建，滚动位置没有重置：第二页卡片仍在屏上。
    expect(find.text('餐厅全案设计项目'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击瀑布流卡片进入全屏详情页，返回后滚动位置保持', (tester) async {
    final repo = FakeHomeRepository([
      [insJson(), modelJson()],
      [designJson(), goodsJson()],
    ]);
    await pumpHomeApp(tester, repo);

    // 点击首屏卡片 → 全屏详情占位页（卡片较高，先滚入视口再点）。
    await tester.ensureVisible(find.text('灵感标题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('灵感标题'));
    await tester.pumpAndSettle();
    expect(find.text('内容详情建设中，敬请期待'), findsOneWidget);

    // 返回后详情页关闭。
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('内容详情建设中，敬请期待'), findsNothing);

    // 滚动到第二页卡片上屏，进详情再返回，滚动位置不重置。
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -2000),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('餐厅全案设计项目'), findsOneWidget);

    await tester.tap(find.text('餐厅全案设计项目'));
    await tester.pumpAndSettle();
    expect(find.text('内容详情建设中，敬请期待'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('餐厅全案设计项目'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
