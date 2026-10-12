import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/home/data/models/feed_item.dart';


Map<String, dynamic> insJson({
  String? insType = '1',
  String? title = '灵感标题',
  String? fileUrl,
  String nick = '无敌喇叭',
  int likeNum = 99,
  String venueType = '景观',
  List<String>? labels,
  bool isPro = false,
}) {
  return {
    'bizId': 'ins-1',
    'imageUrl': 'https://img.example/ins.jpg',
    'imgWide': 1000,
    'imgHigh': 1500,
    'type': 1,
    'createTime': null,
    'hoverIns': {
      'insId': 'ins-1',
      'insTitle': title,
      'insDesc': null,
      'isPro': isPro,
      'insType': int.parse(insType!),
      'coverImgUrl': 'https://img.example/ins.jpg',
      'venueType': venueType,
      'labels': labels,
      'isLike': false,
      'likeNum': likeNum,
      'userId': 'u1',
      'userNick': nick,
      'userAvatar': 'https://img.example/avatar.png',
      'imgWidth': 1000,
      'imgHeight': 1500,
      'fileUrl': fileUrl,
    },
    'hoverModel': null,
    'hoverGoods': null,
    'hoverDesign': null,
  };
}

Map<String, dynamic> modelJson() => {
      'bizId': 'model-1',
      'imageUrl': 'https://img.example/model.png',
      'imgWide': 2048,
      'imgHigh': 2048,
      'type': 3,
      'createTime': '2025-12-30 16:44:43',
      'hoverIns': null,
      'hoverModel': {
        'spuId': 'spu-1',
        'modelId': 'model-1',
        'modelNumber': 'N1',
        'modelName': '南洋混合会所-pro',
        'modelCover': 'https://img.example/model.png',
        'modelLabel': '',
        'modelVersion': 'PRO',
        'modelType': 'indoor',
        'modelDesc': '描述',
        'userId': 'u2',
        'authorName': '用户1915',
        'authorAvatar': 'https://img.example/avatar2.png',
        'sales': '200',
        'useCnt': '200',
        'modelSkuItems': [
          {'skuId': 'sku-1', 'amount': 1, 'price': 16, 'originalPrice': 30, 'limit': 1, 'addLimit': 1, 'specName': '1'}
        ],
        'firstFree': false,
        'minPrice': 16,
        'minPriceAmount': 1,
        'modelLike': '0',
        'likeCnt': 99,
        'userLike': false,
        'payType': 'tops',
      },
      'hoverGoods': null,
      'hoverDesign': null,
    };

Map<String, dynamic> designJson() => {
      'bizId': 'design-1',
      'imageUrl': 'https://img.example/design.jpg',
      'imgWide': 1267,
      'imgHigh': 838,
      'type': 5,
      'createTime': '2026-02-05 18:00:30',
      'hoverIns': null,
      'hoverModel': null,
      'hoverGoods': null,
      'hoverDesign': {
        'designId': 'design-1',
        'designName': '餐厅全案设计项目',
        'labels': '广东省,东莞市,设计需求',
        'price': '100000',
        'partNum': 3,
        'userId': 'u3',
      },
    };

Map<String, dynamic> goodsJson() => {
      'bizId': 'goods-1',
      'imageUrl': 'https://img.example/goods.jpg',
      'imgWide': 800,
      'imgHigh': 800,
      'type': 4,
      'createTime': null,
      'hoverIns': null,
      'hoverModel': null,
      'hoverGoods': {
        'goodsId': 'goods-1',
        'goodsName': '商品名称商品名称',
        'shopName': '店铺名称',
        'shopAvatar': 'https://img.example/shop.png',
        'price': '9999',
        'sales': '200+',
        'score': '99',
      },
      'hoverDesign': null,
    };

void main() {
  group('FeedItem.fromJson', () {
    test('type=1 hoverIns 解析为图片灵感卡', () {
      final item = FeedItem.fromJson(insJson());
      final card = item as InsFeedItem;
      expect(card.bizId, 'ins-1');
      expect(card.imageUrl, 'https://img.example/ins.jpg');
      expect(card.imgWide, 1000);
      expect(card.imgHigh, 1500);
      expect(card.title, '灵感标题');
      expect(card.isVideo, isFalse);
      expect(card.authorNick, '无敌喇叭');
      expect(card.authorAvatar, 'https://img.example/avatar.png');
      expect(card.likeNum, 99);
      expect(card.tags, ['景观']);
    });

    test('type=2 insType=2 且带 fileUrl 解析为视频灵感卡', () {
      final item = FeedItem.fromJson(
          insJson(insType: '2', title: null, fileUrl: 'https://v.example/a.mp4'));
      final card = item as InsFeedItem;
      expect(card.isVideo, isTrue);
      expect(card.videoUrl, 'https://v.example/a.mp4');
      expect(card.title, '');
    });

    test('hoverIns.labels 非空时覆盖 venueType 作为标签', () {
      final item = FeedItem.fromJson(insJson(labels: ['现代', '工业风']));
      expect((item as InsFeedItem).tags, ['现代', '工业风']);
    });

    test('hoverIns.labels 为逗号分隔字符串时也能解析', () {
      final json = insJson();
      (json['hoverIns'] as Map<String, dynamic>)['labels'] = '卧室,现代';
      expect((FeedItem.fromJson(json) as InsFeedItem).tags, ['卧室', '现代']);
    });

    test('hoverIns.labels 为单个字符串标签时解析为单元素', () {
      final json = insJson();
      (json['hoverIns'] as Map<String, dynamic>)['labels'] = '卧室';
      expect((FeedItem.fromJson(json) as InsFeedItem).tags, ['卧室']);
    });

    test('type=3 hoverModel 解析为模型卡', () {
      final item = FeedItem.fromJson(modelJson());
      final card = item as ModelFeedItem;
      expect(card.bizId, 'model-1');
      expect(card.title, '南洋混合会所-pro');
      expect(ModelFeedItem.badge, '模型');
      expect(card.paid, isTrue);
      expect(card.priceText, '¥16/1次');
      expect(card.salesText, '已售200');
      expect(card.authorNick, '用户1915');
      expect(card.likeNum, 99);
      expect(card.tags, isNotEmpty); // 限免1次 或 无
    });

    test('type=3 firstFree=true 时 tag 为 限免1次 且 paid=false', () {
      final json = modelJson();
      (json['hoverModel'] as Map<String, dynamic>)['firstFree'] = true;
      final card = FeedItem.fromJson(json) as ModelFeedItem;
      expect(card.paid, isFalse);
      expect(card.tags, contains('限免1次'));
    });

    test('type=5 hoverDesign 解析为竞选卡', () {
      final item = FeedItem.fromJson(designJson());
      final card = item as DesignFeedItem;
      expect(card.title, '餐厅全案设计项目');
      expect(card.tags, ['广东省', '东莞市', '设计需求']);
      expect(card.priceText, '¥100000');
      expect(card.partNumText, '3人参与');
    });

    test('type=4 hoverGoods 解析为好物卡', () {
      final item = FeedItem.fromJson(goodsJson());
      final card = item as GoodsFeedItem;
      expect(card.title, '商品名称商品名称');
      expect(card.shopName, '店铺名称');
      expect(card.priceText, '¥9999');
      expect(card.salesText, '200+');
      expect(card.scoreText, '99');
    });

    test('未知 type 抛 FormatException', () {
      final json = insJson()..['type'] = 99;
      expect(() => FeedItem.fromJson(json), throwsFormatException);
    });

    test('hoverIns 缺失抛 FormatException', () {
      final json = insJson()..['hoverIns'] = null;
      expect(() => FeedItem.fromJson(json), throwsFormatException);
    });

    test('imgWide/imgHigh 为 0 时 aspectRatio 退回 1', () {
      final json = insJson()..['imgHigh'] = 0;
      expect((FeedItem.fromJson(json) as InsFeedItem).aspectRatio, 1);
    });
  });
}
