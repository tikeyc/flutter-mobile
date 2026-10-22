import 'package:dio/dio.dart' show CancelToken;
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
    this.hasMore = true,
    this.error,
  });

  final List<FeedItem> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  HomeFeedState copyWith({
    List<FeedItem>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) =>
      HomeFeedState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 首页瀑布流：进入自动加载，上拉按 pageNumber 递增取下一页。
class HomeFeedNotifier extends Notifier<HomeFeedState> {
  bool _disposed = false;

  /// 页面级取消令牌，销毁时取消所有未完成请求。
  final CancelToken _cancelToken = CancelToken();

  /// 接口约定首页从第 2 页开始请求。
  static const int _firstPage = 2;
  int _nextPage = _firstPage;

  // 快速甩动时每帧都会触发上拉，成功加载后短时间内节流，避免请求轰炸。
  DateTime? _lastLoadMoreAt;
  static const Duration _loadMoreThrottle = Duration(seconds: 1);

  @override
  HomeFeedState build() {
    ref.onDispose(() {
      _disposed = true;
      _cancelToken.cancel('页面销毁');
    });
    Future.microtask(loadInitial);
    return const HomeFeedState(loading: true);
  }

  Future<void> loadInitial() async {
    if (_disposed) return;
    _nextPage = _firstPage;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await ref
          .read(homeRepoProvider)
          .fetchInsPage(pageNumber: _nextPage, cancelToken: _cancelToken);
      if (_disposed) return;
      _nextPage++;
      state = state.copyWith(
        items: page.items,
        loading: false,
        hasMore: page.hasMore,
      );
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
    if (_disposed || state.loading || state.loadingMore || !state.hasMore) {
      return;
    }
    final last = _lastLoadMoreAt;
    if (last != null && DateTime.now().difference(last) < _loadMoreThrottle) {
      return;
    }
    state = state.copyWith(loadingMore: true);
    try {
      final page = await ref
          .read(homeRepoProvider)
          .fetchInsPage(pageNumber: _nextPage, cancelToken: _cancelToken);
      if (_disposed) return;
      _lastLoadMoreAt = DateTime.now();
      _nextPage++;
      // 偏移分页遇到新内容插入时条目会跨页位移，按 bizId 去重兜底。
      final seen = state.items.map((e) => e.bizId).toSet();
      final merged = [...state.items, ...page.items.where((e) => seen.add(e.bizId))];
      state = state.copyWith(
        items: merged,
        loadingMore: false,
        hasMore: page.hasMore,
      );
    } catch (_) {
      if (_disposed) return;
      // 加载更多失败静默处理，保留已有数据供下次上拉重试；
      // 失败不记节流时间也不推进页码，允许原地重试。
      state = state.copyWith(loadingMore: false);
    }
  }
}

final homeFeedProvider =
    NotifierProvider<HomeFeedNotifier, HomeFeedState>(HomeFeedNotifier.new);
