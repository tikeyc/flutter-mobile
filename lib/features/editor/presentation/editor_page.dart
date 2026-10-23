import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/editor_providers.dart';
import 'widgets/editor_toolbar.dart';
import 'widgets/paint_canvas.dart';

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

  ui.Image? _image;
  String? _loadedPath;
  Size? _boardSize;
  bool _decoding = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _imageSub = ref.listenManual(
      editorProvider.select((s) => s.image),
      (_, next) {
        if (next != null) _loadImage(next);
      },
    );
    final image = ref.read(editorProvider).image;
    if (image != null) _loadImage(image);
  }

  @override
  void dispose() {
    _imageSub?.close();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadImage(XFile file) async {
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
    setState(() {
      _controller = DrawingController();
      _image = image;
      _loadedPath = file.path;
      _decoding = false;
    });
    // 旧画布子树在本帧结束后才卸载，届时再释放旧 controller。
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  /// 右上角关闭按钮：删除当前图片，回到选图占位（不离开本页）。
  void _deleteImage() {
    ref.read(editorProvider.notifier).clearImage();
    final old = _controller;
    setState(() {
      _controller = DrawingController();
      _image = null;
      _loadedPath = null;
      _boardSize = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
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
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: Column(
        children: [
          _navBar(),
          Expanded(child: _imageArea(context)),
          _generateButton(),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => EditorToolbar(
              selectedTool: state.currentTool,
              onToolSelected: (tool) =>
                  ref.read(editorProvider.notifier).selectTool(tool),
              onUndo: _controller.canUndo() ? _controller.undo : null,
              onRedo: _controller.canRedo() ? _controller.redo : null,
              onReset: _controller.canClear() ? _controller.clear : null,
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

  Widget _imageArea(BuildContext context) {
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
        // 保证所见即所得。
        _boardSize = containImageSize(image, constraints.biggest);
        final loadedPath = _loadedPath!;
        return ColoredBox(
          color: AppColors.bg2,
          child: Stack(
            children: [
              Center(
                child: PaintCanvas(
                  key: ValueKey<String>(loadedPath),
                  controller: _controller,
                  image: image,
                  size: _boardSize!,
                  tool: ref.read(editorProvider).currentTool,
                ),
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
