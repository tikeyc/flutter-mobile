sealed class FeedItem {
  const FeedItem({
    required this.bizId,
    required this.imageUrl,
    required this.imgWide,
    required this.imgHigh,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    final map = switch (type) {
      1 || 2 => InsFeedItem._from(json, (json['hoverIns'] as Map?)?.cast<String, dynamic>()),
      3 => ModelFeedItem._from(json, (json['hoverModel'] as Map?)?.cast<String, dynamic>()),
      4 => GoodsFeedItem._from(json, (json['hoverGoods'] as Map?)?.cast<String, dynamic>()),
      5 => DesignFeedItem._from(json, (json['hoverDesign'] as Map?)?.cast<String, dynamic>()),
      _ => throw FormatException('未知的首页卡片类型: $type'),
    };
    return map;
  }

  final String bizId;
  final String imageUrl;
  final int imgWide;
  final int imgHigh;

  /// 图片宽高比，异常值退回 1（1:1）。
  double get aspectRatio =>
      imgWide > 0 && imgHigh > 0 ? imgWide / imgHigh : 1;
}

/// 灵感卡（图片/视频），hoverIns。
class InsFeedItem extends FeedItem {
  const InsFeedItem({
    required super.bizId,
    required super.imageUrl,
    required super.imgWide,
    required super.imgHigh,
    required this.title,
    required this.isVideo,
    required this.videoUrl,
    required this.authorNick,
    required this.authorAvatar,
    required this.likeNum,
    required this.tags,
  });

  static InsFeedItem _from(Map<String, dynamic> json, Map<String, dynamic>? ins) {
    if (ins == null) throw const FormatException('灵感卡缺少 hoverIns');
    // 后端 labels 可能是 List 也可能是逗号分隔字符串。
    final rawLabels = ins['labels'];
    final labels = switch (rawLabels) {
      List l => l.map((e) => e.toString()).where((e) => e.isNotEmpty).toList(),
      String s => s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      _ => const <String>[],
    };
    return InsFeedItem(
      bizId: json['bizId'] as String,
      imageUrl: (ins['coverImgUrl'] as String?)?.isNotEmpty == true
          ? ins['coverImgUrl'] as String
          : json['imageUrl'] as String,
      imgWide: (json['imgWide'] as num?)?.toInt() ?? 0,
      imgHigh: (json['imgHigh'] as num?)?.toInt() ?? 0,
      title: (ins['insTitle'] as String?) ?? '',
      isVideo: ins['insType'] == 2,
      videoUrl: ins['fileUrl'] as String?,
      authorNick: ins['userNick'] as String? ?? '',
      authorAvatar: ins['userAvatar'] as String? ?? '',
      likeNum: (ins['likeNum'] as num?)?.toInt() ?? 0,
      tags: labels.isNotEmpty
          ? labels
          : [(ins['venueType'] as String? ?? '')].where((e) => e.isNotEmpty).toList(),
    );
  }

  final String title;
  final bool isVideo;
  final String? videoUrl;
  final String authorNick;
  final String authorAvatar;
  final int likeNum;
  final List<String> tags;
}

/// 模型卡，hoverModel。
class ModelFeedItem extends FeedItem {
  const ModelFeedItem({
    required super.bizId,
    required super.imageUrl,
    required super.imgWide,
    required super.imgHigh,
    required this.title,
    required this.paid,
    required this.priceText,
    required this.salesText,
    required this.authorNick,
    required this.authorAvatar,
    required this.likeNum,
    required this.tags,
  });

  static ModelFeedItem _from(Map<String, dynamic> json, Map<String, dynamic>? model) {
    if (model == null) throw const FormatException('模型卡缺少 hoverModel');
    final firstFree = model['firstFree'] == true;
    final minPrice = (model['minPrice'] as num?)?.toDouble();
    final amount = (model['minPriceAmount'] as num?)?.toInt() ?? 1;
    final sales = int.tryParse(model['sales']?.toString() ?? '') ?? 0;
    final likeCnt = (model['likeCnt'] as num?)?.toInt()
        ?? int.tryParse(model['modelLike']?.toString() ?? '') ?? 0;
    return ModelFeedItem(
      bizId: json['bizId'] as String,
      imageUrl: json['imageUrl'] as String,
      imgWide: (json['imgWide'] as num?)?.toInt() ?? 0,
      imgHigh: (json['imgHigh'] as num?)?.toInt() ?? 0,
      title: model['modelName'] as String? ?? '',
      paid: !firstFree,
      priceText: minPrice != null ? '¥${_trimNum(minPrice)}/$amount次' : '',
      salesText: sales > 0 ? '已售$sales' : '',
      authorNick: model['authorName'] as String? ?? '',
      authorAvatar: model['authorAvatar'] as String? ?? '',
      likeNum: likeCnt,
      tags: [
        if (firstFree) '限免1次',
        if ((model['modelVersion'] as String? ?? '').isNotEmpty) model['modelVersion'] as String,
      ],
    );
  }

  /// 徽章文案固定为「模型」。
  static const String badge = '模型';

  final String title;
  final bool paid;
  final String priceText;
  final String salesText;
  final String authorNick;
  final String authorAvatar;
  final int likeNum;
  final List<String> tags;

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();
}

/// 竞选卡（设计需求），hoverDesign。
class DesignFeedItem extends FeedItem {
  const DesignFeedItem({
    required super.bizId,
    required super.imageUrl,
    required super.imgWide,
    required super.imgHigh,
    required this.title,
    required this.priceText,
    required this.partNum,
    required this.tags,
  });

  static DesignFeedItem _from(Map<String, dynamic> json, Map<String, dynamic>? design) {
    if (design == null) throw const FormatException('竞选卡缺少 hoverDesign');
    final partNum = (design['partNum'] as num?)?.toInt() ?? 0;
    return DesignFeedItem(
      bizId: json['bizId'] as String,
      imageUrl: json['imageUrl'] as String,
      imgWide: (json['imgWide'] as num?)?.toInt() ?? 0,
      imgHigh: (json['imgHigh'] as num?)?.toInt() ?? 0,
      title: design['designName'] as String? ?? '',
      priceText: '¥${design['price'] ?? ''}',
      partNum: partNum,
      tags: (design['labels'] as String? ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }

  final String title;
  final String priceText;
  final int partNum;

  String get partNumText => partNum > 0 ? '$partNum人参与' : '';
  final List<String> tags;
}

/// 好物卡（商品），hoverGoods。
class GoodsFeedItem extends FeedItem {
  const GoodsFeedItem({
    required super.bizId,
    required super.imageUrl,
    required super.imgWide,
    required super.imgHigh,
    required this.title,
    required this.priceText,
    required this.salesText,
    required this.scoreText,
    required this.shopName,
    required this.shopAvatar,
  });

  /// hoverGoods 字段名后端尚未提供样本，先按惯例命名。
  static GoodsFeedItem _from(Map<String, dynamic> json, Map<String, dynamic>? goods) {
    if (goods == null) throw const FormatException('好物卡缺少 hoverGoods');
    return GoodsFeedItem(
      bizId: json['bizId'] as String,
      imageUrl: json['imageUrl'] as String,
      imgWide: (json['imgWide'] as num?)?.toInt() ?? 0,
      imgHigh: (json['imgHigh'] as num?)?.toInt() ?? 0,
      title: (goods['goodsName'] as String?) ?? '',
      priceText: '¥${goods['price'] ?? ''}',
      // sales 后端已带文案（如 "200+"），为空时显示「已售0」由 UI 层兜底。
      salesText: (goods['sales'] as String?) ?? '',
      scoreText: (goods['score'] as String?) ?? '',
      shopName: (goods['shopName'] as String?) ?? '',
      shopAvatar: (goods['shopAvatar'] as String?) ?? '',
    );
  }

  final String title;
  final String priceText;
  final String salesText;
  final String scoreText;
  final String shopName;
  final String shopAvatar;
}
