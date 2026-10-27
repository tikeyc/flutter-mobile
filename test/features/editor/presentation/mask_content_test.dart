import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/editor/application/editor_providers.dart';
import 'package:intuly/features/editor/application/mask_image.dart';
import 'package:intuly/features/editor/application/mask_content.dart';
import 'package:intuly/features/editor/presentation/widgets/paint_canvas.dart';

/// 全透明画布背景，避免测试 PNG 自带颜色干扰 mask 像素断言。
Future<ui.Image> transparentImage(WidgetTester tester) async {
  late ui.Image image;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder);
    image = await recorder.endRecording().toImage(300, 300);
  });
  addTearDown(image.dispose);
  return image;
}

Future<ui.Image> buildMaskImage(
  WidgetTester tester,
  List<num> mask,
  int width,
  int height,
) async {
  late ui.Image image;
  await tester.runAsync(() async {
    image = await maskToImage(mask, width: width, height: height);
  });
  addTearDown(image.dispose);
  return image;
}

Future<void> pumpCanvas(
  WidgetTester tester, {
  required DrawingController controller,
  required ui.Image image,
  required EditorTool tool,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: PaintCanvas(
            controller: controller,
            image: image,
            size: const Size(300, 300),
            tool: tool,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 16));
}

class Export {
  const Export(this.rgba, this.width, this.height);

  final ByteData rgba;
  final int width;
  final int height;

  int channelAt(int x, int y, int c) =>
      rgba.getUint8(((y * width + x) * 4) + c);
}

Future<Export> exportRgba(
  WidgetTester tester,
  DrawingController controller,
) async {
  late Export result;
  await tester.runAsync(() async {
    final data = await controller.getImageData(pixelRatio: 1.0);
    expect(data, isNotNull);
    final codec = await ui.instantiateImageCodec(data!.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    final rgba = (await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!;
    result = Export(rgba, image.width, image.height);
    image.dispose();
  });
  return result;
}

void main() {
  test('maskToRgba 将 >0 判为选中，颜色与 Web 端一致', () {
    final rgba = maskToRgba([0, 1, -0.5, 0.2], width: 2, height: 2);

    expect(rgba, hasLength(16));
    expect(rgba.sublist(0, 4), [0, 0, 0, 0]);
    expect(rgba.sublist(4, 8), [0, 200, 100, 115]);
    expect(rgba.sublist(8, 12), [0, 0, 0, 0]);
    expect(rgba.sublist(12, 16), [0, 200, 100, 115]);
  });

  test('maskToRgba 长度与尺寸不匹配抛 ArgumentError', () {
    expect(
      () => maskToRgba([1, 1, 1], width: 2, height: 2),
      throwsArgumentError,
    );
  });

  testWidgets('MaskContent 入历史后可导出，且可被橡皮擦擦除', (tester) async {
    final background = await transparentImage(tester);
    final controller = DrawingController();
    addTearDown(controller.dispose);
    await pumpCanvas(
      tester,
      controller: controller,
      image: background,
      tool: EditorTool.brush,
    );

    final mask = await buildMaskImage(tester, List<num>.filled(4 * 4, 1), 4, 4);
    controller.addContent(MaskContent(image: mask));
    await tester.pump(const Duration(milliseconds: 16));

    var rgba = await exportRgba(tester, controller);
    expect(rgba.channelAt(150, 150, 0), 0);
    expect(rgba.channelAt(150, 150, 1), 200);
    expect(rgba.channelAt(150, 150, 2), 100);
    expect(rgba.channelAt(150, 150, 3), 115);

    controller.undo();
    await tester.pump(const Duration(milliseconds: 16));
    rgba = await exportRgba(tester, controller);
    expect(rgba.channelAt(150, 150, 3), 0);

    controller.redo();
    await pumpCanvas(
      tester,
      controller: controller,
      image: background,
      tool: EditorTool.eraser,
    );
    final origin = tester.getRect(find.byType(RawImage)).topLeft;
    final gesture = await tester.startGesture(origin + const Offset(50, 150));
    await gesture.moveTo(origin + const Offset(250, 150));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));

    rgba = await exportRgba(tester, controller);
    expect(rgba.channelAt(150, 150, 3), 0);
    expect(tester.takeException(), isNull);
  });
}
