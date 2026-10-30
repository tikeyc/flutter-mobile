import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_providers.dart';

/// 涂抹画笔：主色、60% 不透明度，笔迹下的图片仍可见。
const double kBrushWidth = 24;
const double kBrushOpacity = 0.6;

/// 橡皮擦宽度。
const double kEraserWidth = 32;

/// 按图片宽高比将尺寸限制在 maxSize 内（BoxFit.contain）。
Size containImageSize(ui.Image image, Size maxSize) {
  if (maxSize.isEmpty) return Size.zero;
  final scale = math.min(
    maxSize.width / image.width,
    maxSize.height / image.height,
  );
  return Size(image.width * scale, image.height * scale);
}

/// flutter_drawing_board 画布：以图片为背景，上方叠加绘制层。
///
/// [PaintCanvas.size] 是可用区域（视口）尺寸，图片按 contain 居中显示。
/// 双指缩放/平移基于原始指针监听，不参与手势竞技场，所以涂抹、橡皮、
/// 智能点选任意工具下都能缩放；缩放开始时丢弃进行中的笔迹。
class PaintCanvas extends StatefulWidget {
  const PaintCanvas({
    super.key,
    required this.controller,
    required this.image,
    required this.size,
    this.tool = EditorTool.brush,
    this.onSmartSelectTap,
    this.previewMask,
    this.maskBusy = false,
  });

  final DrawingController controller;
  final ui.Image image;

  /// 画布可用区域（视口）尺寸；图片在其中按 contain 居中。
  final Size size;
  final EditorTool tool;

  /// 智能点选回调，参数为相对画布区域的归一化坐标（0~1）。
  final ValueChanged<Offset>? onSmartSelectTap;

  /// 待确认的选区预览（智能点选/自动抠图共用），原图分辨率；所有权归调用方。
  final ui.Image? previewMask;

  /// 选区推理中，显示进度指示。
  final bool maskBusy;

  @override
  State<PaintCanvas> createState() => _PaintCanvasState();
}

class _PaintCanvasState extends State<PaintCanvas> {
  static const double _minScale = 1;
  static const double _maxScale = 4;

  /// 当前按下的指针（视口坐标），用于双指缩放。
  final Map<int, Offset> _pointers = <int, Offset>{};

  double _scale = 1;

  /// 内容左上角在视口中的位置；1x 时为图片居中偏移。
  Offset _offset = Offset.zero;

  /// 缩放/平移矩阵独立放 ValueNotifier：双指移动时只重建 Transform，
  /// 不重建画板子树（DrawingBoard/GetSize/画笔都保持不变）。
  final ValueNotifier<Matrix4> _matrix = ValueNotifier<Matrix4>(
    Matrix4.identity(),
  );

  Timer? _deepLayerTimer;

  bool _pinching = false;
  double _pinchStartScale = 1;
  double _pinchStartSpan = 0;
  Offset _pinchStartFocal = Offset.zero;
  Offset _pinchStartOffset = Offset.zero;

  Size get _viewport => widget.size;

  Size get _boardSize => containImageSize(widget.image, _viewport);

  Offset get _centeredOffset {
    final board = _boardSize;
    return Offset(
      (_viewport.width - board.width) / 2,
      (_viewport.height - board.height) / 2,
    );
  }

  @override
  void initState() {
    super.initState();
    _offset = _centeredOffset;
    _matrix.value = _transformMatrix;
    _applyTool(widget.tool);
    widget.controller.addListener(_onHistoryChanged);
  }

  @override
  void didUpdateWidget(covariant PaintCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onHistoryChanged);
      widget.controller.addListener(_onHistoryChanged);
      _deepLayerTimer?.cancel();
    }
    if (oldWidget.tool != widget.tool) _applyTool(widget.tool);
    if (oldWidget.size != widget.size || oldWidget.image != widget.image) {
      _resetZoom();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onHistoryChanged);
    _deepLayerTimer?.cancel();
    _matrix.dispose();
    super.dispose();
  }

  void _applyTool(EditorTool tool) {
    switch (tool) {
      // 用单 path 贝塞尔线条（SimpleLine）：整条笔迹一次 drawPath 绘制，
      // 透明度均匀为 60%；SmoothLine 分段绘制圆头相互重叠，会叠加成近不透明。
      case EditorTool.brush:
        widget.controller
          ..setPaintContent(SimpleLine(useBezierCurve: true))
          ..setStyle(
            color: AppColors.primary.withValues(alpha: kBrushOpacity),
            strokeWidth: kBrushWidth,
            isAntiAlias: true,
          );
      case EditorTool.eraser:
        widget.controller
          ..setPaintContent(Eraser())
          ..setStyle(
            strokeWidth: kEraserWidth,
            isAntiAlias: true,
          );
      case EditorTool.smartSelect:
      case EditorTool.autoCutout:
        // 选区类工具：不改画笔配置，画布输入由 IgnorePointer 禁用。
        break;
    }
  }

  bool get _inputEnabled =>
      widget.tool == EditorTool.brush || widget.tool == EditorTool.eraser;

  /// 选区类工具共用绿色 mask 预览层与推理进度指示。
  bool get _isMaskTool =>
      widget.tool == EditorTool.smartSelect ||
      widget.tool == EditorTool.autoCutout;

  bool get _selecting =>
      widget.tool == EditorTool.smartSelect &&
      widget.onSmartSelectTap != null;

  void _handleSelectTap(TapUpDetails details) {
    final size = _boardSize;
    if (size.isEmpty) return;
    widget.onSmartSelectTap!(
      Offset(
        (details.localPosition.dx / size.width).clamp(0.0, 1.0),
        (details.localPosition.dy / size.height).clamp(0.0, 1.0),
      ),
    );
  }

  Matrix4 get _transformMatrix => Matrix4.identity()
    ..setEntry(0, 0, _scale)
    ..setEntry(1, 1, _scale)
    ..setEntry(0, 3, _offset.dx)
    ..setEntry(1, 3, _offset.dy);

  void _resetZoom() {
    final centered = _centeredOffset;
    if (_scale == 1 && _offset == centered) return;
    _scale = 1;
    _offset = centered;
    _matrix.value = _transformMatrix;
  }

  /// 包内 `_DeepPainter` 每次提交笔迹都把全部历史重新录制进图层，且缓存图
  /// 就绪后不会自动重绘 —— 于是之后每一帧都要重放整段历史，笔迹越多越慢。
  /// 这里在缓存图就绪后补一次重绘，让它改走「只画一张缓存图」的快路径。
  void _onHistoryChanged() {
    _deepLayerTimer?.cancel();
    final controller = widget.controller;
    // 包内提交后不会清掉旧缓存图，先置空：缓存图刷新前的重绘只能实时重录，
    // 否则会拿上一版缓存图走快路径，把刚提交的笔迹吞掉。
    controller.cachedImage = null;

    ui.Image? notified;
    var ticks = 0;
    var stable = 0;
    _deepLayerTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final image = controller.cachedImage;
      if (!mounted || widget.controller != controller || ++ticks > 90) {
        timer.cancel();
        return;
      }
      if (image == null || identical(image, notified)) {
        // 还在等重录完成；或缓存图已稳定（没有新的重录在路上），停止轮询。
        if (image != null && ++stable > 15) timer.cancel();
        return;
      }
      notified = image;
      stable = 0;
      // 包内没有公开的「重录底层」接口，只能直接通知它的重绘监听器。
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      controller.realPainter?.notifyListeners();
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length != 2) return;

    // 第二指落下即视为缩放：丢弃第一指可能已画出的笔迹。
    _discardInProgressStroke();
    _pinching = true;
    _pinchStartScale = _scale;
    _pinchStartOffset = _offset;
    final points = _pointers.values.toList(growable: false);
    _pinchStartSpan = (points[0] - points[1]).distance;
    _pinchStartFocal = (points[0] + points[1]) / 2;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (!_pinching) return;
    final points = _pointers.values.toList(growable: false);
    if (points.length < 2 || _pinchStartSpan <= 0) return;

    final focal = (points[0] + points[1]) / 2;
    final span = (points[0] - points[1]).distance;
    final scale =
        (_pinchStartScale * span / _pinchStartSpan).clamp(_minScale, _maxScale);
    // 起始焦点下的内容始终跟随当前焦点：围绕双指中心缩放/平移。
    final offset = focal -
        (_pinchStartFocal - _pinchStartOffset) * (scale / _pinchStartScale);
    final clamped = _clampOffset(offset, scale);
    if (clamped == _offset && scale == _scale) return;
    _scale = scale;
    _offset = clamped;
    _matrix.value = _transformMatrix;
  }

  void _onPointerEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length >= 2 || !_pinching) return;
    _pinching = false;
    if (_scale < 1.05) _resetZoom();
  }

  void _discardInProgressStroke() {
    final controller = widget.controller;
    if (!controller.hasPaintingContent) return;
    final length = controller.getHistory.length;
    // 包内没有“丢弃已移动笔迹”的公开接口：endDraw 会提交，这里提交后
    // 立刻撤回并把这条从历史尾部移除，避免缩放留下划痕。
    controller.endDraw();
    if (controller.getHistory.length > length) {
      controller.undo();
      controller.getHistory.removeLast();
    }
  }

  /// 缩放后内容小于视口时居中，大于视口时限制在视口内，避免拖出空白。
  Offset _clampOffset(Offset offset, double scale) {
    final viewport = _viewport;
    final board = _boardSize;
    double align(double value, double content, double extent) {
      final scaled = content * scale;
      if (scaled <= extent) return (extent - scaled) / 2;
      return value.clamp(extent - scaled, 0.0);
    }

    return Offset(
      align(offset.dx, board.width, viewport.width),
      align(offset.dy, board.height, viewport.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewport = _viewport;
    final board = _boardSize;
    return SizedBox(
      width: viewport.width,
      height: viewport.height,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: ClipRect(
          child: Stack(
            children: [
              ValueListenableBuilder<Matrix4>(
                valueListenable: _matrix,
                builder: (context, matrix, child) => Transform(
                  key: const Key('canvas-transform'),
                  alignment: Alignment.topLeft,
                  transform: matrix,
                  child: child,
                ),
                child: SizedBox(
                  width: board.width,
                  height: board.height,
                  child: Stack(
                    children: [
                      IgnorePointer(
                        ignoring: !_inputEnabled,
                        child: DrawingBoard(
                          controller: widget.controller,
                          boardPanEnabled: false,
                          boardScaleEnabled: false,
                          // 画布是轴对齐矩形，硬边裁剪省掉每帧的抗锯齿裁剪。
                          clipBehavior: Clip.hardEdge,
                          background: SizedBox(
                            width: board.width,
                            height: board.height,
                            child: RawImage(
                              image: widget.image,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                      ),
                      if (_selecting)
                        Positioned.fill(
                          child: GestureDetector(
                            key: const Key('smart-select-surface'),
                            behavior: HitTestBehavior.opaque,
                            onTapUp: _handleSelectTap,
                          ),
                        ),
                      if (_isMaskTool && widget.previewMask != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              key: const Key('mask-preview'),
                              painter: _PreviewMaskPainter(
                                widget.previewMask!,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // 界面指示层不跟随图片缩放。
              if (_isMaskTool && widget.maskBusy)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        key: const Key('mask-busy'),
                        width: 32,
                        height: 32,
                        child: const CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewMaskPainter extends CustomPainter {
  _PreviewMaskPainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.low
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _PreviewMaskPainter oldDelegate) =>
      oldDelegate.image != image;
}
