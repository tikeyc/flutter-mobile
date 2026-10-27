import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/editor_providers.dart';
import '../application/mask_content.dart';
import '../application/smart_select_providers.dart';
import '../data/sam_segmenter.dart' show SamMask, kDemoImageAsset;
import 'widgets/editor_toolbar.dart';
import 'widgets/paint_canvas.dart';

/// 已应用到画布的选区：图层 + 原始 mask（用于再次点按的命中检测）。
typedef _AppliedSelection = ({MaskContent content, SamMask mask});

/// AI 修图页：顶部导航栏 + 图片预览区 + 立即生成 + 底部修图工具栏。
/// 涂抹/橡皮擦基于 flutter_drawing_board 画布实现，撤销/重做/重置走其历史栈。
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, required this.onClose});

  /// 返回上一页回调（外壳切回首页分支）。
  final VoidCallback onClose;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  /// 导出分辨率倍数上限，防止超大原图导出爆内存。
  static const double _maxExportRatio = 4.0;

  DrawingController _controller = DrawingController();
  ProviderSubscription<XFile?>? _imageSub;

  /// 提前持有，dispose 时不能再通过 ref 访问 provider。
  late final SmartSelectController _smartSelect;

  ui.Image? _image;
  String? _loadedPath;
  Size? _boardSize;
  bool _decoding = false;
  bool _exporting = false;

  /// 已应用到画布的选区，用于「再点已选区域 → 取消选区」。
  final List<_AppliedSelection> _appliedSelections = [];
  _AppliedSelection? _cancelTarget;

  @override
  void initState() {
    super.initState();
    _smartSelect = ref.read(smartSelectProvider.notifier);
    _imageSub = ref.listenManual(
      editorProvider.select((s) => s.image),
      (_, next) {
        if (next != null) {
          _loadImage(next, demo: ref.read(editorProvider).imageIsDemo);
        }
      },
    );
    final image = ref.read(editorProvider).image;
    if (image != null) {
      _loadImage(image, demo: ref.read(editorProvider).imageIsDemo);
    }
  }

  @override
  void dispose() {
    _imageSub?.close();
    _smartSelect.cancelPreview();
    _disposeController(_controller);
    super.dispose();
  }

  /// 当前图片是否为内置示例图（且已成功解码）。
  bool get _imageIsDemo =>
      _image != null && ref.read(editorProvider).imageIsDemo;

  Future<void> _loadImage(XFile file, {required bool demo}) async {
    setState(() => _decoding = true);
    ui.Image? image;
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      image = (await codec.getNextFrame()).image;
    } catch (_) {
      image = null;
    }
    if (!mounted) {
      image?.dispose();
      return;
    }
    // 解码期间用户已换图：丢弃过期结果，交给最新一次加载。
    if (ref.read(editorProvider).image != file) {
      image?.dispose();
      return;
    }
    if (image == null) {
      setState(() => _decoding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片加载失败，请重试')),
      );
      return;
    }
    final old = _controller;
    ref.read(smartSelectProvider.notifier).cancelPreview();
    setState(() {
      _controller = DrawingController();
      _image = image;
      _loadedPath = demo ? kDemoImageAsset : file.path;
      _decoding = false;
      _appliedSelections.clear();
      _cancelTarget = null;
    });
    // 智能点选只对示例图可用：换成普通图片时回退涂抹。
    if (!demo &&
        ref.read(editorProvider).currentTool == EditorTool.smartSelect) {
      ref.read(editorProvider.notifier).selectTool(EditorTool.brush);
    }
    // 旧画布子树在本帧结束后才卸载，届时再释放旧 controller。
    WidgetsBinding.instance.addPostFrameCallback((_) => _disposeController(old));
    if (demo &&
        ref.read(editorProvider).currentTool == EditorTool.smartSelect) {
      unawaited(_prepareSmartSelect());
    }
  }

  /// 加载示例图对应的 embedding 与 ONNX 模型（幂等，重复选择工具不重复加载）。
  Future<void> _prepareSmartSelect() async {
    final image = _image;
    if (image == null) return;
    await ref.read(smartSelectProvider.notifier).ensureReady(
          imageWidth: image.width,
          imageHeight: image.height,
        );
  }

  void _disposeController(DrawingController controller) {
    for (final content in controller.getHistory) {
      if (content is MaskContent) content.dispose();
    }
    controller.dispose();
  }

  void _clearCanvas() {
    final masks = _controller.getHistory.whereType<MaskContent>().toList();
    _controller.clear();
    _appliedSelections.clear();
    _cancelTarget = null;
    if (masks.isEmpty) return;
    // 本帧仍可能引用旧图层，下一帧后再释放。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final mask in masks) {
        mask.dispose();
      }
    });
  }

  /// 智能点选工具的入口：示例图/模型加载失败或确认取消都保持原状态。
  Future<void> _onToolSelected(EditorTool tool) async {
    _cancelTarget = null;
    if (tool != EditorTool.smartSelect) {
      ref.read(smartSelectProvider.notifier).cancelPreview();
      ref.read(editorProvider.notifier).selectTool(tool);
      return;
    }

    if (_imageIsDemo) {
      ref.read(editorProvider.notifier).selectTool(tool);
      await _prepareSmartSelect();
      return;
    }
    if (_image == null) {
      ref.read(editorProvider.notifier).selectTool(tool);
      await _openDemoImage();
      return;
    }
    final confirmed = await _confirmSwitchToDemo();
    if (!confirmed || !mounted) return;
    ref.read(editorProvider.notifier).selectTool(tool);
    await _openDemoImage();
  }

  Future<bool> _confirmSwitchToDemo() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('智能点选'),
        content: const Text('智能点选目前仅支持内置示例图，切换后会清空当前涂抹内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('smart-select-switch'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('切换示例图'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openDemoImage() async {
    try {
      final data = await rootBundle.load(kDemoImageAsset);
      if (!mounted) return;
      final file = XFile.fromData(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        mimeType: 'image/png',
        name: 'IntelligenSelection.png',
      );
      ref.read(editorProvider.notifier).setImage(file, demo: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('示例图加载失败，请重试')),
      );
    }
  }

  void _onSmartSelectTap(Offset normalized) {
    final image = _image;
    if (image == null) return;
    final applied = _appliedSelectionAt(normalized);
    if (applied != null) {
      // 点按已应用的选区：只提供「取消选区」，不再重新推理。
      ref.read(smartSelectProvider.notifier).cancelPreview();
      setState(() => _cancelTarget = applied);
      return;
    }
    setState(() => _cancelTarget = null);
    final smartSelect = ref.read(smartSelectProvider.notifier);
    // 再次点按预览中的已选区域：保留当前预览，不重复推理。
    if (smartSelect.isSelected(normalized)) return;
    unawaited(
      smartSelect.selectAt(
        normalized,
        imageWidth: image.width,
        imageHeight: image.height,
      ),
    );
  }

  /// 点按是否命中某个「已应用且当前可见」的选区图层（取最上层）。
  _AppliedSelection? _appliedSelectionAt(Offset normalized) {
    final history = _controller.getHistory;
    _appliedSelections.removeWhere((s) => !history.contains(s.content));
    for (final selection in _appliedSelections.reversed) {
      final index = history.indexOf(selection.content);
      // 已撤销（不可见）的选区不参与命中。
      if (index < 0 || index >= _controller.currentIndex) continue;
      final mask = selection.mask;
      final x = (normalized.dx * mask.width).floor().clamp(0, mask.width - 1);
      final y = (normalized.dy * mask.height).floor().clamp(0, mask.height - 1);
      if (mask.values[y * mask.width + x] > 0) return selection;
    }
    return null;
  }

  void _applySelection() {
    final smartSelect = ref.read(smartSelectProvider.notifier);
    final mask = smartSelect.currentMask;
    final content = smartSelect.takePreview();
    if (content == null || mask == null) return;
    _controller.addContent(content);
    setState(() {
      _appliedSelections.add((content: content, mask: mask));
      _cancelTarget = null;
    });
  }

  void _cancelSelection() {
    setState(() => _cancelTarget = null);
    ref.read(smartSelectProvider.notifier).cancelPreview();
  }

  /// 取消点按区域已应用的选区：把该图层从绘制历史中移除。
  void _cancelAppliedSelection() {
    final target = _cancelTarget;
    if (target == null) return;
    setState(() => _cancelTarget = null);
    _appliedSelections.remove(target);
    final history = _controller.getHistory;
    final index = history.indexOf(target.content);
    if (index < 0) return;
    history.removeAt(index);
    // 移除的是当前可见图层时，当前指针同步 -1 并刷新画布。
    if (index < _controller.currentIndex) _controller.undo();
    // 本帧仍可能引用旧图层，下一帧后再释放。
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => target.content.dispose(),
    );
  }

  /// 右上角关闭按钮：删除当前图片，回到选图占位（不离开本页）。
  void _deleteImage() {
    ref.read(editorProvider.notifier).clearImage();
    ref.read(smartSelectProvider.notifier).cancelPreview();
    if (ref.read(editorProvider).currentTool == EditorTool.smartSelect) {
      ref.read(editorProvider.notifier).selectTool(EditorTool.brush);
    }
    final old = _controller;
    setState(() {
      _controller = DrawingController();
      _image = null;
      _loadedPath = null;
      _boardSize = null;
      _appliedSelections.clear();
      _cancelTarget = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _disposeController(old));
  }

  Future<void> _generate() async {
    final image = _image;
    final boardSize = _boardSize;
    if (image == null || boardSize == null || _exporting) return;
    setState(() => _exporting = true);
    // 按原图分辨率导出（逻辑尺寸 → 原图像素），限制上限防爆内存。
    final ratio = (image.width / boardSize.width).clamp(1.0, _maxExportRatio);
    final data = await _controller.getImageData(pixelRatio: ratio);
    final bytes = data?.buffer.asUint8List();
    if (!mounted) return;
    setState(() => _exporting = false);
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生成失败，请重试')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('生成预览'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            Text(
              'PNG · ${(bytes.length / 1024).toStringAsFixed(1)} KB',
              style: AppTextStyles.body14.copyWith(color: AppColors.text3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorProvider);
    final smartState = ref.watch(smartSelectProvider);
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: Column(
        children: [
          _navBar(),
          Expanded(child: _imageArea(context, state, smartState)),
          _generateButton(),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => EditorToolbar(
              selectedTool: state.currentTool,
              onToolSelected: _onToolSelected,
              onUndo: _controller.canUndo() ? _controller.undo : null,
              onRedo: _controller.canRedo() ? _controller.redo : null,
              onReset: _controller.canClear() ? _clearCanvas : null,
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部导航栏：左侧返回上一页，右侧关闭按钮删除当前图片。
  Widget _navBar() {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: SizedBox(
        height: 44,
        child: Stack(
          children: [
            const Center(child: Text('AI 修图', style: AppTextStyles.title16)),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                key: const Key('editor-back'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: AppColors.text1,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                key: const Key('editor-close'),
                behavior: HitTestBehavior.opaque,
                onTap: _deleteImage,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SvgPicture.asset(
                      AppIcons.close,
                      width: 22,
                      height: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageArea(
    BuildContext context,
    EditorState state,
    SmartSelectState smartState,
  ) {
    final image = _image;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (image == null) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _decoding ? null : () => _showPickSheet(context),
            child: ColoredBox(
              color: AppColors.bg2,
              child: Center(
                child: _decoding
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                            color: AppColors.text3,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '点击选择图片',
                            style: AppTextStyles.body14.copyWith(
                              color: AppColors.text3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        }
        // 画布逻辑尺寸 = 图片 contain 后的显示尺寸，导出时按同尺寸渲染，
        // 保证所见即所得；画布组件本身铺满可用区域，放大时可利用全部空间。
        _boardSize = containImageSize(image, constraints.biggest);
        final loadedPath = _loadedPath!;
        return ColoredBox(
          color: AppColors.bg2,
          child: Stack(
            children: [
              PaintCanvas(
                key: ValueKey<String>(loadedPath),
                controller: _controller,
                image: image,
                size: constraints.biggest,
                tool: state.currentTool,
                onSmartSelectTap: state.currentTool == EditorTool.smartSelect
                    ? _onSmartSelectTap
                    : null,
                previewMask: state.currentTool == EditorTool.smartSelect
                    ? smartState.preview
                    : null,
                smartSelectBusy: smartState.inferring,
              ),
              if (state.currentTool == EditorTool.smartSelect)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 56,
                  child: Center(child: _smartSelectBar(smartState)),
                ),
              Positioned(
                right: 12,
                bottom: 12,
                child: GestureDetector(
                  key: const Key('editor-replace-image'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _decoding ? null : () => _showPickSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '替换图片',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 智能点选状态条：加载/错误/操作提示/确认预览/取消已应用选区。
  Widget _smartSelectBar(SmartSelectState smart) {
    if (_cancelTarget != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(22),
        ),
        child: TextButton(
          key: const Key('smart-select-cancel'),
          onPressed: _cancelAppliedSelection,
          child: const Text('取消选区', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    if (smart.status == SmartSelectStatus.loading) {
      return _smartPill('正在加载智能点选模型…');
    }
    if (smart.status == SmartSelectStatus.error) {
      return _smartPill('智能点选不可用：${smart.errorMessage ?? '未知错误'}');
    }
    if (smart.inferring) {
      return IgnorePointer(child: _smartPill('正在识别选区…'));
    }
    if (smart.preview != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              key: const Key('smart-select-cancel'),
              onPressed: _cancelSelection,
              child: const Text(
                '取消选区',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              key: const Key('smart-select-apply'),
              onPressed: _applySelection,
              child: const Text(
                '应用选区',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
    }
    return IgnorePointer(
      child: _smartPill('点击图片选择要保留的区域'),
    );
  }

  Widget _smartPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }

  Widget _generateButton() {
    final enabled = _image != null && !_decoding && !_exporting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GestureDetector(
        key: const Key('editor-generate'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _generate : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          decoration: BoxDecoration(
            color: enabled ? AppColors.primary : AppColors.border4,
            borderRadius: BorderRadius.circular(22),
          ),
          alignment: Alignment.center,
          child: Text(
            _exporting ? '生成中…' : '立即生成',
            style: AppTextStyles.body14.copyWith(
              color: enabled ? AppColors.textWhite : AppColors.text3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPickSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<XFile>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () async {
                final image = await ref
                    .read(imagePickServiceProvider)
                    .pickFromGallery(sheetContext);
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(image);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () async {
                final image = await ref
                    .read(imagePickServiceProvider)
                    .pickFromCamera(sheetContext);
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(image);
                }
              },
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref.read(editorProvider.notifier).setImage(picked);
    }
  }
}
