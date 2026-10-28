import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/editor/application/mask_image.dart';

void main() {
  test('maskToAlphaRgba 选中像素为不透明白色，未选中完全透明', () {
    final rgba = maskToAlphaRgba(
      [1, 0, 0, 2],
      width: 2,
      height: 2,
    );

    expect(rgba[3], 255, reason: '第 1 个像素选中');
    expect(rgba.sublist(0, 3), [255, 255, 255], reason: '白色用于裁剪');
    expect(rgba.sublist(4, 8), [0, 0, 0, 0], reason: '第 2 个像素未选中');
    expect(rgba[15], 255, reason: '第 4 个像素选中');
  });

  test('maskToAlphaRgba 长度不匹配时抛错', () {
    expect(
      () => maskToAlphaRgba([1, 0], width: 4, height: 4),
      throwsArgumentError,
    );
  });
}
