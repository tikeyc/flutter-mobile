import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/editor_providers.dart';
import 'widgets/editor_toolbar.dart';

/// AI 修图页：图片预览区 + 底部修图工具栏。
/// 点击预览区可更换本地图片或拍照；工具按钮暂只切换选中态，涂抹等
/// 编辑能力后续由 flutter_fabric 接入。
class EditorPage extends ConsumerWidget {
  const EditorPage({super.key, required this.onClose});

  /// 右上角关闭回调（外壳切回首页分支）。
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorProvider);
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _imageArea(context, ref, state.imagePath)),
              EditorToolbar(
                selectedTool: state.currentTool,
                onToolSelected: (tool) =>
                    ref.read(editorProvider.notifier).selectTool(tool),
                // 撤销/重做/重置先预留，后续由 flutter_fabric 涂鸦历史栈接管。
                onUndo: () {},
                onRedo: () {},
                onReset: () {},
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 16,
            child: GestureDetector(
              key: const Key('editor-close'),
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: SvgPicture.asset(AppIcons.close, width: 24, height: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageArea(BuildContext context, WidgetRef ref, String? imagePath) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPickSheet(context, ref),
      child: ColoredBox(
        color: AppColors.bg2,
        child: Center(
          child: imagePath == null
              ? Column(
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
                )
              : Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
        ),
      ),
    );
  }

  Future<void> _showPickSheet(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () async {
                final path = await ref
                    .read(imagePickServiceProvider)
                    .pickFromGallery(sheetContext);
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(path);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () async {
                final path = await ref
                    .read(imagePickServiceProvider)
                    .pickFromCamera(sheetContext);
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(path);
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
