import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/auth/data/models/slide_challenge.dart';
import 'package:intuly/features/auth/presentation/slide_captcha/slide_geometry.dart';

import '../../../../helpers/test_images.dart';

void main() {
  // 原图 594x356，拼图块 100x100，top 120；渲染宽 297 → scale 0.5
  final g = SlideGeometry(SlideChallenge.fromJson(slideJson()), 297);

  test('按渲染宽度缩放尺寸', () {
    expect(g.scale, 0.5);
    expect(g.renderHeight, 178);
    expect(g.pieceWidth, 50);
    expect(g.pieceTop, 60);
  });

  test('maxOffset 让拼图块和把手都不越界', () {
    expect(g.maxOffset, 297 - 50); // 拼图块 50 > 把手 44
    expect(g.clamp(-10), 0);
    expect(g.clamp(999), 247);
  });

  test('moveWidth = round(offset / scale)，与 Web 端一致', () {
    expect(g.moveWidthFor(100), 200);
    expect(g.moveWidthFor(100.3), 201);
  });
}
