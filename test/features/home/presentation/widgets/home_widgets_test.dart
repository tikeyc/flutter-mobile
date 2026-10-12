import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/core/theme/app_colors.dart';
import 'package:intuly/features/home/data/models/feed_item.dart';
import 'package:intuly/features/home/presentation/widgets/feed_card.dart';
import 'package:intuly/features/home/presentation/widgets/feed_grid.dart';
import 'package:intuly/features/home/presentation/widgets/home_bottom_nav.dart';
import 'package:intuly/features/home/presentation/widgets/home_nav_bar.dart';

import '../../fixtures/hotlist_fixtures.dart';

FeedItem parse(Map<String, dynamic> json) => FeedItem.fromJson(json);

Widget wrap(Widget child) => MaterialApp(
      theme: ThemeData(scaffoldBackgroundColor: AppColors.bg2),
      home: Scaffold(body: child),
    );

void main() {
  group('FeedCard', () {
    testWidgets('灵感图片卡：标题、tag、作者、点赞数', (tester) async {
      final card = parse(insJson(title: '现代工业多巴胺街头装置品'));
      await tester.pumpWidget(wrap(FeedCard(item: card, width: 176)));

      expect(find.text('现代工业多巴胺街头装置品'), findsOneWidget);
      expect(find.text('景观'), findsOneWidget);
      expect(find.text('无敌喇叭'), findsOneWidget);
      expect(find.text('99'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('灵感视频卡显示播放角标', (tester) async {
      final card = parse(
          insJson(insType: '2', title: null, fileUrl: 'https://v.example/a.mp4'));
      await tester.pumpWidget(wrap(FeedCard(item: card, width: 176)));

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('模型卡：模型角标、价格、销量、金色星星', (tester) async {
      final card = parse(modelJson());
      await tester.pumpWidget(wrap(FeedCard(item: card, width: 176)));

      expect(find.text('模型'), findsOneWidget);
      expect(find.text('南洋混合会所-pro'), findsOneWidget);
      expect(find.text('¥16/1次'), findsOneWidget);
      expect(find.text('已售200'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
    });

    testWidgets('竞选卡：价格与参与数', (tester) async {
      final card = parse(designJson());
      await tester.pumpWidget(wrap(FeedCard(item: card, width: 176)));

      expect(find.text('餐厅全案设计项目'), findsOneWidget);
      expect(find.text('广东省'), findsOneWidget);
      expect(find.text('¥100000'), findsOneWidget);
      expect(find.text('3人参与'), findsOneWidget);
    });

    testWidgets('好物卡：商品名、价格、店铺行', (tester) async {
      final card = parse(goodsJson());
      await tester.pumpWidget(wrap(FeedCard(item: card, width: 176)));

      expect(find.text('商品名称商品名称'), findsOneWidget);
      expect(find.text('¥9999'), findsOneWidget);
      expect(find.text('店铺名称'), findsOneWidget);
    });
  });

  group('FeedGrid', () {
    testWidgets('多卡片渲染为两列且不溢出', (tester) async {
      final items = [
        parse(insJson()),
        parse(modelJson()),
        parse(designJson()),
        parse(goodsJson()),
      ];
      await tester.pumpWidget(wrap(SingleChildScrollView(
        child: FeedGrid(items: items),
      )));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FeedCard), findsNWidgets(4));
    });
  });

  group('HomeNavBar', () {
    testWidgets('渲染 4 个 Tab，选中项为话题且点击切换', (tester) async {
      var selected = -1;
      await tester.pumpWidget(wrap(HomeNavBar(
        tabs: const ['话题', '活动', '灵感', '热门'],
        selected: 0,
        onTabSelected: (i) => selected = i,
      )));

      expect(find.text('话题'), findsOneWidget);
      expect(find.text('活动'), findsOneWidget);
      expect(find.text('灵感'), findsOneWidget);
      expect(find.text('热门'), findsOneWidget);

      await tester.tap(find.text('热门'));
      expect(selected, 3);
    });

    testWidgets('内容避开状态栏，背景延伸到状态栏后面', (tester) async {
      const statusBarHeight = 40.0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.bg2),
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: statusBarHeight)),
          child: Scaffold(
            appBar: HomeNavBar(tabs: const ['话题', '活动', '灵感', '热门'], selected: 0),
          ),
        ),
      ));

      // Scaffold 为 appBar 预留 44 + 状态栏高度，整条背景覆盖状态栏区域。
      expect(tester.getSize(find.byType(HomeNavBar)).height, 44 + statusBarHeight);
      // Tab 内容不得进入状态栏区域。
      expect(
        tester.getTopLeft(find.text('话题')).dy,
        greaterThanOrEqualTo(statusBarHeight),
      );
    });
  });

  group('HomeBottomNav', () {
    testWidgets('渲染 4 个文字 tab，选中态高亮', (tester) async {
      await tester.pumpWidget(wrap(HomeBottomNav(
        tabs: const ['灵感社区', '模型广场', '需求大厅', '好物商城'],
        selected: 0,
      )));

      expect(find.text('灵感社区'), findsOneWidget);
      expect(find.text('模型广场'), findsOneWidget);
      expect(find.text('需求大厅'), findsOneWidget);
      expect(find.text('好物商城'), findsOneWidget);

      // 选中项颜色为主色：通过 Text style 校验第一个 tab。
      final text = tester.widget<Text>(find.text('灵感社区'));
      expect(text.style?.color, AppColors.primary);
      final unselected = tester.widget<Text>(find.text('模型广场'));
      expect(unselected.style?.color, AppColors.text2);
    });

    testWidgets('内容避开系统手势条，背景延伸到手势条后面', (tester) async {
      const bottomInset = 24.0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.bg2),
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
          child: Scaffold(
            bottomNavigationBar: HomeBottomNav(
              tabs: const ['灵感社区', '模型广场', '需求大厅', '好物商城'],
              selected: 0,
            ),
          ),
        ),
      ));

      // 整条高度 = 内容 56 + 手势条 inset，且贴住屏幕底边。
      final navRect = tester.getRect(find.byType(HomeBottomNav));
      expect(navRect.height, 56 + bottomInset);
      expect(navRect.bottom, 600);
      // 文字不得进入手势条区域。
      expect(
        tester.getBottomLeft(find.text('灵感社区')).dy,
        lessThanOrEqualTo(600 - bottomInset),
      );
    });
  });
}
