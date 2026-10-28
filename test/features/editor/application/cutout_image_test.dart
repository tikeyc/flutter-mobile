import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/editor/application/cutout_image.dart';
import 'package:intuly/features/editor/data/mask_data.dart';

const MaskData _emptyMask = MaskData(
  values: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  width: 4,
  height: 4,
);

/// 4x4 四象限图：左上红、右上绿、左下蓝、右下白。
Future<ui.Image> buildQuadrantImage(WidgetTester tester) async {
  late ui.Image image;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    void quadrant(double dx, double dy, Color color) {
      canvas.drawRect(
        Rect.fromLTWH(dx, dy, 2, 2),
        Paint()..color = color,
      );
    }

    quadrant(0, 0, const Color(0xFFFF0000));
    quadrant(2, 0, const Color(0xFF00FF00));
    quadrant(0, 2, const Color(0xFF0000FF));
    quadrant(2, 2, const Color(0xFFFFFFFF));
    image = await recorder.endRecording().toImage(4, 4);
  });
  addTearDown(image.dispose);
  return image;
}

/// 解码 PNG 并取回 RGBA 像素（预乘 alpha）。
Future<({int width, int height, Uint8List rgba})> decodePng(
  WidgetTester tester,
  Uint8List bytes,
) async {
  late int width;
  late int height;
  late Uint8List rgba;
  await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    width = image.width;
    height = image.height;
    rgba = data!.buffer.asUint8List();
    image.dispose();
  });
  return (width: width, height: height, rgba: rgba);
}

int alphaAt(({int width, int height, Uint8List rgba}) png, int x, int y) =>
    png.rgba[(y * png.width + x) * 4 + 3];

Color colorAt(({int width, int height, Uint8List rgba}) png, int x, int y) {
  final offset = (y * png.width + x) * 4;
  return Color.fromARGB(
    png.rgba[offset + 3],
    png.rgba[offset],
    png.rgba[offset + 1],
    png.rgba[offset + 2],
  );
}

/// 测试用笔迹：填充指定矩形。
class FillContent extends PaintContent {
  FillContent(this.rect, this.color);

  final Rect rect;
  final Color color;

  @override
  void draw(Canvas canvas, Size size, bool deeper) {
    canvas.drawRect(rect, Paint()..color = color);
  }

  @override
  void drawing(Offset nowPoint) {}

  @override
  void startDraw(Offset startPoint) {}

  @override
  PaintContent copy() => this;

  @override
  Map<String, dynamic> toContentJson() => const {};
}

/// 测试用橡皮擦：以 clear 混合模式擦除指定矩形。
class ClearContent extends PaintContent {
  ClearContent(this.rect);

  final Rect rect;

  @override
  void draw(Canvas canvas, Size size, bool deeper) {
    canvas.drawRect(rect, Paint()..blendMode = BlendMode.clear);
  }

  @override
  void drawing(Offset nowPoint) {}

  @override
  void startDraw(Offset startPoint) {}

  @override
  PaintContent copy() => this;

  @override
  Map<String, dynamic> toContentJson() => const {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('maskBounds 返回选中像素的外接框', () {
    const mask = MaskData(
      values: [0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0],
      width: 4,
      height: 4,
    );

    expect(maskBounds(mask), const Rect.fromLTRB(1, 1, 3, 3));
  });

  test('maskBounds 全空时返回 null', () {
    expect(maskBounds(_emptyMask), isNull);
  });

  test('unionMasks 逐像素取并集', () {
    const first = MaskData(
      values: [1, 0, 0, 0],
      width: 2,
      height: 2,
    );
    const second = MaskData(
      values: [0, 1, 0, 0],
      width: 2,
      height: 2,
    );

    final union = unionMasks([first, second]);

    expect(union.width, 2);
    expect(union.height, 2);
    expect(union.values[0], greaterThan(0));
    expect(union.values[1], greaterThan(0));
    expect(union.values[2], 0);
    expect(union.values[3], 0);
  });

  test('unionMasks 尺寸不一致时抛错', () {
    expect(
      () => unionMasks([
        _emptyMask,
        const MaskData(values: [1], width: 1, height: 1),
      ]),
      throwsArgumentError,
    );
  });

  testWidgets('cutoutPng 紧贴主体裁剪，保留主体像素', (tester) async {
    final image = await buildQuadrantImage(tester);
    // 只选中右下白色象限，外接框为 2x2。
    const mask = MaskData(
      values: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1],
      width: 4,
      height: 4,
    );

    final bytes = await tester.runAsync(
      () => cutoutPng(image: image, mask: mask, scale: 1),
    );
    final png = await decodePng(tester, bytes!);

    expect(png.width, 2);
    expect(png.height, 2);
    expect(alphaAt(png, 0, 0), 255);
    expect(alphaAt(png, 1, 1), 255);
  });

  testWidgets('cutoutPng 主体外区域的透明像素保留', (tester) async {
    final image = await buildQuadrantImage(tester);
    // 只选中四角，外接框覆盖整图，中间透明。
    const mask = MaskData(
      values: [1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1],
      width: 4,
      height: 4,
    );

    final bytes = await tester.runAsync(
      () => cutoutPng(image: image, mask: mask, scale: 1),
    );
    final png = await decodePng(tester, bytes!);

    expect(png.width, 4);
    expect(png.height, 4);
    expect(alphaAt(png, 0, 0), 255);
    expect(alphaAt(png, 3, 0), 255);
    expect(alphaAt(png, 0, 3), 255);
    expect(alphaAt(png, 3, 3), 255);
    expect(alphaAt(png, 1, 1), 0);
    expect(alphaAt(png, 2, 2), 0);
  });

  testWidgets('cutoutPng 按 scale 缩放输出尺寸', (tester) async {
    final image = await buildQuadrantImage(tester);
    const mask = MaskData(
      values: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1],
      width: 4,
      height: 4,
    );

    final bytes = await tester.runAsync(
      () => cutoutPng(image: image, mask: mask, scale: 3),
    );
    final png = await decodePng(tester, bytes!);

    expect(png.width, 6);
    expect(png.height, 6);
  });

  testWidgets('cutoutPng 把涂抹区域并入主体，导出该处原图', (tester) async {
    final image = await buildQuadrantImage(tester);
    // 选区是左上红色象限，笔迹落在右下白色象限。
    const mask = MaskData(
      values: [1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      width: 4,
      height: 4,
    );

    final bytes = await tester.runAsync(
      () => cutoutPng(
        image: image,
        mask: mask,
        scale: 1,
        boardSize: const Size(8, 8),
        strokes: [
          FillContent(const Rect.fromLTWH(4, 4, 4, 4), const Color(0xFF00FFFF)),
        ],
      ),
    );
    final png = await decodePng(tester, bytes!);

    // 笔迹并入后外接框扩展为整图。
    expect(png.width, 4);
    expect(png.height, 4);
    expect(colorAt(png, 0, 0), const Color(0xFFFF0000));
    // 笔迹处导出的是图片本身（右下白），而不是笔迹颜色。
    expect(colorAt(png, 3, 3), const Color(0xFFFFFFFF));
    expect(alphaAt(png, 0, 3), 0, reason: '既不在选区也无笔迹处保持透明');
  });

  testWidgets('cutoutPng 橡皮擦笔迹从主体区域中挖掉', (tester) async {
    final image = await buildQuadrantImage(tester);
    const fullMask = MaskData(
      values: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
      width: 4,
      height: 4,
    );

    final bytes = await tester.runAsync(
      () => cutoutPng(
        image: image,
        mask: fullMask,
        scale: 1,
        boardSize: const Size(4, 4),
        strokes: [ClearContent(const Rect.fromLTWH(0, 0, 2, 4))],
      ),
    );
    final png = await decodePng(tester, bytes!);

    // 左半被擦掉后外接框紧贴剩余的右半（源图 x=2..4）。
    expect(png.width, 2);
    expect(png.height, 4);
    expect(colorAt(png, 1, 0), const Color(0xFF00FF00));
    expect(colorAt(png, 1, 3), const Color(0xFFFFFFFF));
  });

  testWidgets('cutoutPng 无选中像素时返回 null', (tester) async {
    final image = await buildQuadrantImage(tester);

    final bytes = await tester.runAsync(
      () => cutoutPng(image: image, mask: _emptyMask, scale: 1),
    );

    expect(bytes, isNull);
  });
}
