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
  ValueChanged<Offset>? onSmartSelectTap,
  ui.Image? previewMask,
  bool smartSelectBusy = false,
  Size size = const Size(300, 300),
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: PaintCanvas(
          controller: controller,
          image: image,
          size: size,
          tool: tool,
          onSmartSelectTap: onSmartSelectTap,
          previewMask: previewMask,
          smartSelectBusy: smartSelectBusy,
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
/// 坐标相对画布左上角，避免依赖画布在测试窗口中的位置。
Future<void> dragStroke(WidgetTester tester, Offset from, Offset to) async {
  final origin = tester.getRect(find.byType(RawImage)).topLeft;
  final gesture = await tester.startGesture(origin + from);
  await gesture.moveTo(origin + to);
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 16));
}

Future<ui.Image> buildPreview(WidgetTester tester) async {
  late ui.Image preview;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 60, 40),
      Paint()..color = const Color(0xFF00C864),
    );
    preview = await recorder.endRecording().toImage(60, 40);
  });
  addTearDown(preview.dispose);
  return preview;
}

/// 双指以 [center] 为中心，从 [fromSpan] 横向张到 [toSpan]。
Future<void> pinch(
  WidgetTester tester, {
  required Offset center,
  required double fromSpan,
  required double toSpan,
}) async {
  final first = await tester.createGesture();
  final second = await tester.createGesture();
  await first.down(center - Offset(fromSpan / 2, 0));
  await second.down(center + Offset(fromSpan / 2, 0));
  await tester.pump();
  await first.moveTo(center - Offset(toSpan / 2, 0));
  await second.moveTo(center + Offset(toSpan / 2, 0));
  await tester.pump();
  await first.up();
  await second.up();
  await tester.pump(const Duration(milliseconds: 16));
}

Matrix4 canvasTransform(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const Key('canvas-transform')))
    .transform;

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
    final origin = tester.getRect(find.byType(RawImage)).topLeft;
    final gesture = await tester.startGesture(origin + const Offset(40, 150));
    for (var x = 48.0; x <= 260.0; x += 8) {
      await gesture.moveTo(origin + Offset(x, 150));
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

  testWidgets('智能点选：点按画布输出归一化坐标且不产生笔迹', (tester) async {
    final image = await decodePng(tester);
    final ctrl = DrawingController();
    addTearDown(ctrl.dispose);
    final points = <Offset>[];

    await tester.pumpWidget(canvasApp(
      controller: ctrl,
      image: image,
      tool: EditorTool.smartSelect,
      onSmartSelectTap: points.add,
    ));
    await tester.pump(const Duration(milliseconds: 16));

    final canvasRect = tester.getRect(find.byType(RawImage));
    expect(canvasRect.size, const Size(300, 300));

    await tester.tapAt(canvasRect.center);
    await tester.pump();

    expect(points, hasLength(1));
    expect(points.single.dx, closeTo(0.5, 0.01));
    expect(points.single.dy, closeTo(0.5, 0.01));
    expect(ctrl.getHistory, isEmpty);
  });

  testWidgets('智能点选：画布外点按不触发回调', (tester) async {
    final image = await decodePng(tester);
    final ctrl = DrawingController();
    addTearDown(ctrl.dispose);
    final points = <Offset>[];

    await tester.pumpWidget(canvasApp(
      controller: ctrl,
      image: image,
      tool: EditorTool.smartSelect,
      onSmartSelectTap: points.add,
    ));
    await tester.pump(const Duration(milliseconds: 16));

    final canvasRect = tester.getRect(find.byType(RawImage));
    await tester.tapAt(canvasRect.bottomRight + const Offset(80, 40));
    await tester.pump();

    expect(points, isEmpty);
  });

  testWidgets('智能点选：预览 mask 叠在画布区域、推理中显示进度指示', (tester) async {
    final image = await decodePng(tester);
    final ctrl = DrawingController();
    addTearDown(ctrl.dispose);

    // 预览图由外部负责释放，这里造一张全绿图占位。
    late ui.Image preview;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 60, 40),
        Paint()..color = const Color(0xFF00C864),
      );
      preview = await recorder.endRecording().toImage(60, 40);
    });
    addTearDown(preview.dispose);

    await tester.pumpWidget(canvasApp(
      controller: ctrl,
      image: image,
      tool: EditorTool.smartSelect,
      previewMask: preview,
      smartSelectBusy: true,
    ));
    await tester.pump(const Duration(milliseconds: 16));

    final previewRect = tester.getRect(
      find.byKey(const Key('smart-select-preview')),
    );
    expect(previewRect.size, const Size(300, 300));
    expect(previewRect.topLeft, tester.getRect(find.byType(RawImage)).topLeft);
    expect(find.byKey(const Key('smart-select-busy')), findsOneWidget);
  });

  testWidgets('智能点选：空闲时不显示进度指示，涂抹模式不响应点选', (tester) async {
    final image = await decodePng(tester);
    final ctrl = DrawingController();
    addTearDown(ctrl.dispose);
    final points = <Offset>[];

    await tester.pumpWidget(canvasApp(
      controller: ctrl,
      image: image,
      tool: EditorTool.brush,
      onSmartSelectTap: points.add,
    ));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const Key('smart-select-busy')), findsNothing);
    expect(find.byKey(const Key('smart-select-surface')), findsNothing);

    await tester.tapAt(tester.getRect(find.byType(RawImage)).center);
    await tester.pump();
    expect(points, isEmpty);
  });

  testWidgets('智能点选：预览时不往画布上叠操作按钮', (tester) async {
    final image = await decodePng(tester);
    final ctrl = DrawingController();
    addTearDown(ctrl.dispose);
    final preview = await buildPreview(tester);

    await tester.pumpWidget(canvasApp(
      controller: ctrl,
      image: image,
      tool: EditorTool.smartSelect,
      previewMask: preview,
    ));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('取消选区'), findsNothing);
    expect(find.text('应用选区'), findsNothing);
    expect(find.byKey(const Key('smart-select-cancel')), findsNothing);
    expect(find.byKey(const Key('smart-select-apply')), findsNothing);
  });

  testWidgets('双指张开放大图片，双指捏合回到 1x 并归位', (tester) async {
    final image = await decodePng(tester);
    final ctrl = DrawingController();
    addTearDown(ctrl.dispose);
    final points = <Offset>[];

    await tester.pumpWidget(canvasApp(
      controller: ctrl,
      image: image,
      tool: EditorTool.smartSelect,
      onSmartSelectTap: points.add,
    ));
    await tester.pump(const Duration(milliseconds: 16));

    final center = tester.getRect(find.byType(RawImage)).center;
    await pinch(tester, center: center, fromSpan: 40, toSpan: 80);

    var matrix = canvasTransform(tester);
    final zoomed = matrix.storage[0];
    expect(zoomed, greaterThan(1.2), reason: '双指张开应放大');
    // 平移量被限制在内容边界内，放大后内容仍覆盖视口。
    expect(
      matrix.storage[12],
      inInclusiveRange(300 - 300 * zoomed, 0),
    );
    expect(
      matrix.storage[13],
      inInclusiveRange(300 - 300 * zoomed, 0),
    );
    expect(points, isEmpty, reason: '双指缩放不应触发点选');

    await pinch(tester, center: center, fromSpan: 80, toSpan: 20);

    matrix = canvasTransform(tester);
    expect(matrix.storage[0], closeTo(1.0, 0.01));
    expect(matrix.storage[12], closeTo(0, 0.01));
    expect(matrix.storage[13], closeTo(0, 0.01));
  });

  testWidgets('放大后单指点选坐标仍按原图归一化', (tester) async {
    final image = await decodePng(tester);
    final ctrl = DrawingController();
    addTearDown(ctrl.dispose);
    final points = <Offset>[];

    await tester.pumpWidget(canvasApp(
      controller: ctrl,
      image: image,
      tool: EditorTool.smartSelect,
      onSmartSelectTap: points.add,
    ));
    await tester.pump(const Duration(milliseconds: 16));

    final origin = tester.getRect(find.byType(RawImage)).topLeft;
    await pinch(tester, center: origin + const Offset(150, 150), fromSpan: 40, toSpan: 80);
    final matrix = canvasTransform(tester);
    final scale = matrix.storage[0];
    final offset = Offset(matrix.storage[12], matrix.storage[13]);
    expect(scale, greaterThan(1.2));

    // 屏幕 x=50 经变换反算后的画布坐标，再按 300 归一化。
    const screen = Offset(50, 150);
    final local = (screen - offset) / scale;
    await tester.tapAt(origin + screen);
    await tester.pump();

    expect(points, hasLength(1));
    expect(points.single.dx, closeTo(local.dx / 300, 0.01));
    expect(points.single.dy, closeTo(local.dy / 300, 0.01));
    expect(ctrl.getHistory, isEmpty);
  });

  testWidgets('放大后单指涂抹仍正常产生笔迹', (tester) async {
    final image = await decodePng(tester);
    final ctrl = DrawingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(canvasApp(controller: ctrl, image: image));
    await tester.pump(const Duration(milliseconds: 16));

    final origin = tester.getRect(find.byType(RawImage)).topLeft;
    await pinch(tester, center: origin + const Offset(150, 150), fromSpan: 40, toSpan: 80);
    expect(ctrl.getHistory, isEmpty, reason: '双指缩放不应留下笔迹');

    // 放大后图片超出视口被裁切，按视口内可见的位置画一笔。
    final visible = tester.getRect(find.byType(PaintCanvas)).center;
    final gesture = await tester.startGesture(visible - const Offset(60, 0));
    await gesture.moveTo(visible + const Offset(60, 0));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));

    expect(ctrl.getHistory, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('涂抹中双指缩放：先按下的手指已移动也不留笔迹', (tester) async {
    final image = await decodePng(tester);
    final ctrl = DrawingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(canvasApp(controller: ctrl, image: image));
    await tester.pump(const Duration(milliseconds: 16));

    final rect = tester.getRect(find.byType(RawImage));
    final first = await tester.createGesture();
    final second = await tester.createGesture();
    await first.down(rect.center - const Offset(20, 0));
    await tester.pump();
    // 第一指先滑一小段：包内此时已经开始了这条笔迹。
    await first.moveBy(const Offset(12, 0));
    await tester.pump();
    await second.down(rect.center + const Offset(20, 0));
    await tester.pump();
    await first.moveTo(rect.center - const Offset(60, 0));
    await second.moveTo(rect.center + const Offset(60, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump(const Duration(milliseconds: 16));

    expect(canvasTransform(tester).storage[0], greaterThan(1.2));
    expect(ctrl.getHistory, isEmpty, reason: '双指缩放不应留下笔迹');
    expect(ctrl.canUndo(), isFalse);
  });

  testWidgets('放大后可利用整个可用区域，图片尽量铺满视口', (tester) async {
    final image = await decodePng(tester);
    final ctrl = DrawingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(canvasApp(
      controller: ctrl,
      image: image,
      size: const Size(400, 300),
    ));
    await tester.pump(const Duration(milliseconds: 16));

    final viewport = tester.getRect(find.byType(PaintCanvas));
    expect(viewport.size, const Size(400, 300));
    final base = tester.getRect(find.byType(RawImage));
    expect(base.size, const Size(300, 300), reason: '1x 时按 contain 显示');
    expect(base.center.dx, closeTo(viewport.center.dx, 0.01));
    expect(base.center.dy, closeTo(viewport.center.dy, 0.01));

    await pinch(tester, center: base.center, fromSpan: 40, toSpan: 80);

    // 放大后不再被 1x 的图片框裁剪，可以铺满整个可用区域。
    final zoomed = tester.getRect(find.byType(RawImage));
    expect(zoomed.width, greaterThan(viewport.width));
    expect(zoomed.height, greaterThan(viewport.height));
    expect(zoomed.left, lessThanOrEqualTo(viewport.left + 0.01));
    expect(zoomed.top, lessThanOrEqualTo(viewport.top + 0.01));
    expect(zoomed.right, greaterThanOrEqualTo(viewport.right - 0.01));
    expect(zoomed.bottom, greaterThanOrEqualTo(viewport.bottom - 0.01));
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
