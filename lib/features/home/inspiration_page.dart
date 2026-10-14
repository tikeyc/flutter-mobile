import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../router/app_router.dart';
import 'application/home_providers.dart';
import 'home_page.dart';
import 'presentation/widgets/feed_card.dart';
import 'presentation/widgets/home_nav_bar.dart';

/// 灵感社区（首页默认 tab）：顶部话题 Tab 导航 + 双列瀑布流。
class InspirationPage extends ConsumerStatefulWidget {
  const InspirationPage({super.key});

  @override
  ConsumerState<InspirationPage> createState() => _InspirationPageState();
}

class _InspirationPageState extends ConsumerState<InspirationPage> {
  static const _tabs = ['话题', '活动', '灵感', '热门'];

  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(homeFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: HomeNavBar(
        tabs: _tabs,
        selected: _selectedTab,
        onMenu: () => HomeShellDrawer.maybeOf(context)?.openDrawer(),
        onTabSelected: (i) => setState(() => _selectedTab = i),
      ),
      body: _feedBody(feed),
    );
  }

  Widget _feedBody(HomeFeedState feed) {
    if (feed.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (feed.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => {
                GoRouter.of(context).push(AppRoutes.feedDetail('1')),
              },
              child: const Text('测试跳转详情'),
            ),
            Text(feed.error!, style: const TextStyle(color: AppColors.text3)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.read(homeFeedProvider.notifier).retry(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
          ref.read(homeFeedProvider.notifier).loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childCount: feed.items.length,
              itemBuilder: (context, index) => FeedCard(
                item: feed.items[index],
                onTap: () =>
                    context.push(AppRoutes.feedDetail(feed.items[index].bizId)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: feed.loadingMore
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
