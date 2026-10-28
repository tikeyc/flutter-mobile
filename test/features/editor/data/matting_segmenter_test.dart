import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/editor/data/matting_segmenter.dart';

void main() {
  test('mask 尺寸等比限制在长边 1024 内', () {
    expect(mattingMaskSize(600, 400), (width: 600, height: 400));
    expect(mattingMaskSize(2400, 1200), (width: 1024, height: 512));
    expect(mattingMaskSize(100, 3000), (width: 34, height: 1024));
  });

  test('RGBA 转 NCHW 并按 ImageNet 均值方差归一化', () {
    final rgba = Uint8List(kMattingInputSide * kMattingInputSide * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba[i] = 255;
      rgba[i + 1] = 0;
      rgba[i + 2] = 128;
      rgba[i + 3] = 255;
    }

    final floats = rgbaToNchw(rgba);
    const pixels = kMattingInputSide * kMattingInputSide;
    expect(floats.length, pixels * 3);
    expect(floats[0], closeTo((1 - 0.485) / 0.229, 1e-6));
    expect(floats[pixels], closeTo((0 - 0.456) / 0.224, 1e-6));
    expect(floats[2 * pixels], closeTo((128 / 255 - 0.406) / 0.225, 1e-6));
    expect(floats[pixels - 1], closeTo((1 - 0.485) / 0.229, 1e-6));
  });

  test('RGBA 长度不符抛 ArgumentError', () {
    expect(() => rgbaToNchw(Uint8List(4)), throwsArgumentError);
  });

  test('概率按最大值归一化后以 0.5 阈值二值化', () {
    final probabilities = Float32List.fromList([0, 0, 0, 0.4]);

    final mask = maskFromProbabilities(
      probabilities,
      sourceSide: 2,
      width: 2,
      height: 2,
    );

    expect(mask.values, [0.0, 0.0, 0.0, 1.0]);
    expect(mask.width, 2);
    expect(mask.height, 2);
  });

  test('上采样使用双线性插值，边缘落在阈值两侧', () {
    // 2×2（每行 [0, 1]）放大到 4 列：采样值为 0、0.25、0.75、1。
    final probabilities = Float32List.fromList([0, 1, 0, 1]);

    final mask = maskFromProbabilities(
      probabilities,
      sourceSide: 2,
      width: 4,
      height: 2,
    );

    expect(mask.values.sublist(0, 4), [0.0, 0.0, 1.0, 1.0]);
  });

  test('概率个数不符抛 ArgumentError', () {
    expect(
      () => maskFromProbabilities(
        Float32List(3),
        sourceSide: 2,
        width: 2,
        height: 2,
      ),
      throwsArgumentError,
    );
  });
}
