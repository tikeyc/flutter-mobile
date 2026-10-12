import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/auth/data/models/slide_challenge.dart';

import '../../../helpers/test_images.dart';

void main() {
  test('解析纯 base64', () {
    final c = SlideChallenge.fromJson(slideJson());
    expect(c.captchaId, 'cap-1');
    expect(c.backgroundBytes, kPngBytes);
    expect(c.width, 594);
    expect(c.pieceWidth, 100);
    expect(c.pieceTop, 120);
  });

  test('解析带 data URI 前缀的 base64', () {
    final c = SlideChallenge.fromJson(slideJson(prefix: 'data:image/png;base64,'));
    expect(c.pieceBytes, kPngBytes);
  });

  test('缺字段时抛 FormatException', () {
    expect(() => SlideChallenge.fromJson({'imgCaptchaId': 'x'}), throwsFormatException);
  });
}
