import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/home/application/home_providers.dart';
import 'package:intuly/features/home/data/home_repository.dart';
import 'package:intuly/features/home/data/models/feed_item.dart';
import 'package:intuly/features/home/home_page.dart';
import 'package:intuly/features/home/presentation/widgets/feed_card.dart';

import 'fixtures/hotlist_fixtures.dart';

/// 顺序返回预设页，避免走网络层。
class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository(this.pages);

  final List<List<Map<String, dynamic>>> pages;
  int calls = 0;

  @override
  Future<List<FeedItem>> fetchHotList({required bool first}) async {
    final page = pages[calls < pages.length ? calls : pages.length - 1];
    calls++;
    return page.map((e) => FeedItem.fromJson(e)).toList();
  }
}

void main() {
  testWidgets('首页以瀑布流渲染卡片，上拉触发加载更多', (tester) async {
    final repo = FakeHomeRepository([
      [insJson(), modelJson()],
      [designJson(), goodsJson()],
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [homeRepoProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

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
        ProviderScope.containerOf(tester.element(find.byType(HomePage)));
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [homeRepoProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

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
}
