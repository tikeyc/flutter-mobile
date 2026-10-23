import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/core/theme/app_colors.dart';
import 'package:intuly/features/editor/application/editor_providers.dart';
import 'package:intuly/features/editor/presentation/widgets/paint_canvas.dart';

import '../../../helpers/test_images.dart' show kPngBytes;

/// dart:io/解码等真实异步在 fake async 区不会完成，必须包在 runAsync 里。
Future<ui.Image> decodePng(WidgetTester tester) async {
  late ui.Image image;
  await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(kPngBytes);
    image = (await codec.getNextFrame()).image;
  });
  addTearDown(image.dispose);
  return image;
}

Widget canvasApp({
  required DrawingController controller,
  required ui.Image image,
  EditorTool tool = EditorTool.brush,
}) {
  return MaterialApp(
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
  );
}

Future<DrawingController> pumpCanvas(
  WidgetTester tester, {
  EditorTool tool = EditorTool.brush,
}) async {
  final image = await decodePng(tester);
  final ctrl = DrawingController();
  addTearDown(ctrl.dispose);
  await tester.pumpWidget(canvasApp(controller: ctrl, image: image, tool: tool));
  // 必须带时长推进 fake 时钟，否则包内 SafeState 的零时长 Timer 不触发，
  // 测试结束会报 pending timer。
  await tester.pump(const Duration(milliseconds: 16));
  return ctrl;
}

/// 快速滑一笔：按下立即移动，不停顿（回归 100ms 手势延迟问题）。
Future<void> dragStroke(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from);
  await gesture.moveTo(to);
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('涂抹工具默认为 SimpleLine、主色 60% 不透明度、宽度 24', (tester) async {
    final ctrl = await pumpCanvas(tester);

    expect(ctrl.currentContent, isA<SimpleLine>());
    final config = ctrl.drawConfig.value;
    expect(config.color, AppColors.primary.withValues(alpha: 0.6));
    expect(config.strokeWidth, 24);
  });

  testWidgets('橡皮擦工具为 Eraser、宽度 32', (tester) async {
    final ctrl = await pumpCanvas(tester, tool: EditorTool.eraser);

    expect(ctrl.currentContent, isA<Eraser>());
    expect(ctrl.drawConfig.value.strokeWidth, 32);
  });

  testWidgets('智能点选/自动抠图为占位工具，画布不产笔迹', (tester) async {
    for (final tool in [EditorTool.smartSelect, EditorTool.autoCutout]) {
      final image = await decodePng(tester);
      final ctrl = DrawingController();
      addTearDown(ctrl.dispose);
      await tester.pumpWidget(canvasApp(controller: ctrl, image: image, tool: tool));
      await tester.pump(const Duration(milliseconds: 16));

      await dragStroke(tester, const Offset(40, 40), const Offset(260, 40));
      expect(ctrl.getHistory, isEmpty);
    }
  });

  testWidgets('涂抹笔迹导出像素 alpha 约等于 60%（0.6×255≈153）', (tester) async {
    // 全透明背景：直接造 ui.Image，避免测试 PNG 自带半透明像素干扰。
    late ui.Image transparent;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder);
      transparent = await recorder.endRecording().toImage(300, 300);
    });
    addTearDown(transparent.dispose);
    final ctrl = DrawingController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(canvasApp(controller: ctrl, image: transparent));
    await tester.pump(const Duration(milliseconds: 16));

    // 模拟真实触摸：小步移动（单步大跳会变细线，且宽度模型不同）。
    final gesture = await tester.startGesture(const Offset(40, 150));
    for (var x = 48.0; x <= 260.0; x += 8) {
      await gesture.moveTo(Offset(x, 150));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));

    late ui.Image exported;
    await tester.runAsync(() async {
      final data = await ctrl.getImageData(pixelRatio: 1.0);
      expect(data, isNotNull);
      final codec =
          await ui.instantiateImageCodec(data!.buffer.asUint8List());
      exported = (await codec.getNextFrame()).image;
    });
    addTearDown(exported.dispose);

    final rgba = await tester.runAsync(
      () => exported.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(rgba, isNotNull);
    int alphaAt(int x, int y) =>
        rgba!.getUint8(((y * exported.width + x) * 4) + 3);

    // 笔迹中心：单一 60% alpha 图层，应为 153 左右；若整条 path 被
    // 分段重复绘制（圆帽重叠），会累积到 240+，此处直接证伪。
    final centerAlpha = alphaAt(150, 150);
    expect(centerAlpha, greaterThan(140), reason: '笔迹应带透明度，实际 $centerAlpha');
    expect(centerAlpha, lessThan(165), reason: '笔迹透明度应约 60%，实际 $centerAlpha');
    // 笔迹之外保持透明。
    expect(alphaAt(150, 60), 0);
  });

  testWidgets('画笔按下即画，快速连画两笔无需停顿', (tester) async {
    final ctrl = await pumpCanvas(tester);

    await dragStroke(tester, const Offset(40, 40), const Offset(140, 40));
    await dragStroke(tester, const Offset(40, 80), const Offset(140, 80));

    expect(ctrl.getHistory, hasLength(2));
    expect(ctrl.canUndo(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('涂抹后切橡皮擦，擦除手势立即生效且撤销重做完整还原',
      (tester) async {
    final image = await decodePng(tester);
    final ctrl = DrawingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(canvasApp(
      controller: ctrl,
      image: image,
      tool: EditorTool.brush,
    ));
    await tester.pump(const Duration(milliseconds: 16));
    await dragStroke(tester, const Offset(40, 100), const Offset(260, 100));
    expect(ctrl.getHistory, hasLength(1));

    await tester.pumpWidget(canvasApp(
      controller: ctrl,
      image: image,
      tool: EditorTool.eraser,
    ));
    await tester.pump(const Duration(milliseconds: 16));
    expect(ctrl.currentContent, isA<Eraser>());

    await dragStroke(tester, const Offset(40, 100), const Offset(260, 100));
    expect(ctrl.getHistory, hasLength(2));
    expect(ctrl.getHistory.last, isA<Eraser>());

    ctrl.undo();
    expect(ctrl.canUndo(), isTrue);
    expect(ctrl.canRedo(), isTrue);
    ctrl.redo();
    expect(ctrl.canRedo(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
