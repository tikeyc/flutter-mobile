import 'dart:convert';
import 'dart:typed_data';

/// 合法的 1x1 PNG（base64），供解码和 Image.memory 测试使用。
const String kPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

final Uint8List kPngBytes = base64Decode(kPngBase64);

Map<String, dynamic> slideJson({String prefix = ''}) => {
      'imgCaptchaId': 'cap-1',
      'image': '$prefix$kPngBase64',
      'slide': '$prefix$kPngBase64',
      'width': 594,
      'height': 356,
      'slideWidth': 100,
      'slideHeight': 100,
      'pos': {'width': 300, 'height': 120},
      'errorCnt': 0,
    };
