import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../auth/application/auth_providers.dart';
import 'application/home_providers.dart';
import 'presentation/widgets/feed_grid.dart';
import 'presentation/widgets/home_bottom_nav.dart';
import 'presentation/widgets/home_nav_bar.dart';

/// 首页（灵感广场）：顶部 Tab 导航 + 双列瀑布流 + 底部导航。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const _tabs = ['话题', '活动', '灵感', '热门'];
  static const _bottomTabs = ['灵感社区', '模型广场', '需求大厅', '好物商城'];

  int _selectedTab = 0;
  int _selectedBottom = 0;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(homeFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: HomeNavBar(
        tabs: _tabs,
        selected: _selectedTab,
        onTabSelected: (i) => setState(() => _selectedTab = i),
      ),
      body: _feedBody(feed),
      bottomNavigationBar: HomeBottomNav(
        tabs: _bottomTabs,
        selected: _selectedBottom,
        onTabSelected: (i) => setState(() => _selectedBottom = i),
        // 调试期临时：长按中央按钮退出登录（正式「我的」页完成后移除）。
        onCenterTap: () => ref.read(authProvider.notifier).signOut(),
      ),
    );
  }

  Widget _feedBody(HomeFeedState feed) {
    if (feed.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (feed.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            padding: const EdgeInsets.only(top: 4),
            sliver: SliverToBoxAdapter(child: FeedGrid(items: feed.items)),
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
