import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'models/feed_item.dart';

abstract class HomeRepository {
  /// 首页瀑布流数据。接口无真实分页，每次返回随机一批；
  /// [first] 为 true 时带 isOperational=true。
  Future<List<FeedItem>> fetchHotList({required bool first});
}

class DioHomeRepository implements HomeRepository {
  final Dio _dio;
  DioHomeRepository(this._dio);

  @override
  Future<List<FeedItem>> fetchHotList({required bool first}) async {
    Response<Map<String, dynamic>> res;
    try {
      res = await _dio.get<Map<String, dynamic>>(
        '/cms/home/hotList',
        queryParameters: first ? {'isOperational': true} : null,
      );
    } on DioException catch (e) {
      final err = e.error;
      throw err is ApiException ? err : ApiException.fromDio(e);
    }
    final body = res.data ?? const {};
    final data = body['data'];
    if (data is! List) {
      throw ApiException(status: body['status'] as int?, message: '获取首页数据失败，请重试');
    }
    // 逐项容错：单条脏数据跳过，不拖垮整页 feed。
    final items = <FeedItem>[];
    for (final raw in data) {
      if (raw is! Map) continue;
      try {
        items.add(FeedItem.fromJson(raw.cast<String, dynamic>()));
      } on FormatException {
        continue;
      }
    }
    return items;
  }
}
