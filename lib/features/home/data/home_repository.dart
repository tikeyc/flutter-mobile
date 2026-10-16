import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'models/feed_item.dart';

/// insPage 的一页结果。
class InsPage {
  const InsPage({required this.items, required this.hasMore});

  final List<FeedItem> items;
  final bool hasMore;
}

abstract class HomeRepository {
  /// 首页瀑布流分页数据。
  Future<InsPage> fetchInsPage({
    required int pageNumber,
    int pageSize = 20,
    String venueType = '全部',
  });
}

class DioHomeRepository implements HomeRepository {
  final Dio _dio;
  DioHomeRepository(this._dio);

  @override
  Future<InsPage> fetchInsPage({
    required int pageNumber,
    int pageSize = 20,
    String venueType = '全部',
  }) async {
    Response<Map<String, dynamic>> res;
    try {
      res = await _dio.post<Map<String, dynamic>>(
        '/cms/home/insPage',
        data: {
          'pageNumber': pageNumber,
          'pageSize': pageSize,
          'venueType': venueType,
        },
      );
    } on DioException catch (e) {
      final err = e.error;
      throw err is ApiException ? err : ApiException.fromDio(e);
    }
    final body = res.data ?? const {};
    final data = body['data'];
    final page = data is Map
        ? data.cast<String, dynamic>()
        : const <String, dynamic>{};
    final records = page['records'];
    if (records is! List) {
      throw ApiException(
        status: body['status'] as int?,
        message: '获取首页数据失败，请重试',
      );
    }
    // 逐项容错：单条脏数据跳过，不拖垮整页 feed。
    final items = <FeedItem>[];
    for (final raw in records) {
      if (raw is! Map) continue;
      try {
        items.add(FeedItem.fromJson(raw.cast<String, dynamic>()));
      } on FormatException {
        continue;
      }
    }
    final current = (page['current'] as num?)?.toInt();
    final pages = (page['pages'] as num?)?.toInt();
    return InsPage(
      items: items,
      hasMore: current != null && pages != null
          ? current < pages
          : items.length >= pageSize,
    );
  }
}
