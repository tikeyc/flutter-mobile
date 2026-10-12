import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_providers.dart' show dioProvider;
import '../data/home_repository.dart';
import '../data/models/feed_item.dart';

final homeRepoProvider = Provider<HomeRepository>(
  (ref) => DioHomeRepository(ref.watch(dioProvider)),
);

/// 首页瀑布流状态。
class HomeFeedState {
  const HomeFeedState({
    this.items = const [],
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final List<FeedItem> items;
  final bool loading;
  final bool loadingMore;
  final String? error;

  HomeFeedState copyWith({
    List<FeedItem>? items,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
  }) =>
      HomeFeedState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 首页瀑布流：进入自动加载，上拉加载更多（接口随机返回，按 bizId 去重合并）。
class HomeFeedNotifier extends Notifier<HomeFeedState> {
  bool _disposed = false;

  @override
  HomeFeedState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(loadInitial);
    return const HomeFeedState(loading: true);
  }

  Future<void> loadInitial() async {
    if (_disposed) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await ref.read(homeRepoProvider).fetchHotList(first: true);
      if (_disposed) return;
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        loading: false,
        error: e is ApiException ? e.message : '获取首页数据失败，请重试',
      );
    }
  }

  Future<void> retry() => state.items.isEmpty ? loadInitial() : loadMore();

  Future<void> loadMore() async {
    if (_disposed || state.loading || state.loadingMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final fresh = await ref.read(homeRepoProvider).fetchHotList(first: false);
      if (_disposed) return;
      final seen = state.items.map((e) => e.bizId).toSet();
      final merged = [...state.items, ...fresh.where((e) => seen.add(e.bizId))];
      state = state.copyWith(items: merged, loadingMore: false);
    } catch (_) {
      if (_disposed) return;
      // 加载更多失败静默处理，保留已有数据供下次上拉重试。
      state = state.copyWith(loadingMore: false);
    }
  }
}

final homeFeedProvider =
    NotifierProvider<HomeFeedNotifier, HomeFeedState>(HomeFeedNotifier.new);
