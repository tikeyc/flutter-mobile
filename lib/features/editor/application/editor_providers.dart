import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'image_pick_gallery_io.dart'
    if (dart.library.js_interop) 'image_pick_gallery_web.dart';

/// 修图工具。自动抠图为占位工具，画布交互暂时禁用。
enum EditorTool { brush, smartSelect, autoCutout, eraser }

/// 编辑器状态。
class EditorState {
  const EditorState({
    this.image,
    this.currentTool = EditorTool.brush,
    this.imageIsDemo = false,
  });

  /// 当前编辑图片；null 表示尚未选择。
  /// 用 XFile 承载，原生为文件路径、Web 为 blob URL，统一走 readAsBytes 读图。
  final XFile? image;
  final EditorTool currentTool;

  /// 当前图片是否为内置示例图；智能点选目前只支持示例图。
  final bool imageIsDemo;

  EditorState copyWith({
    XFile? image,
    EditorTool? currentTool,
    bool? imageIsDemo,
  }) {
    return EditorState(
      image: image ?? this.image,
      currentTool: currentTool ?? this.currentTool,
      imageIsDemo: imageIsDemo ?? this.imageIsDemo,
    );
  }
}

/// 编辑器状态：当前图片与选中工具。
final editorProvider = NotifierProvider<EditorNotifier, EditorState>(
  EditorNotifier.new,
);

class EditorNotifier extends Notifier<EditorState> {
  @override
  EditorState build() => const EditorState();

  void setImage(XFile image, {bool demo = false}) {
    state = EditorState(
      image: image,
      currentTool: state.currentTool,
      imageIsDemo: demo,
    );
  }

  /// 删除当前图片，工具选择保留。
  void clearImage() => state = EditorState(currentTool: state.currentTool);

  void selectTool(EditorTool tool) => state = state.copyWith(currentTool: tool);
}

/// 选图服务实例；页面经此触发相册/拍照，抽成 Provider 便于测试替换。
final imagePickServiceProvider = Provider<ImagePickService>(
  (ref) => ImagePickService(),
);

/// 选图服务：相册按平台分支（原生 wechat_assets_picker / Web 文件选择器），
/// 拍照统一走 image_picker。
class ImagePickService {
  final ImagePicker _cameraPicker = ImagePicker();

  /// 从相册选一张图；用户取消返回 null。
  Future<XFile?> pickFromGallery(BuildContext context) =>
      pickGalleryImage(context);

  /// 拍照；用户取消返回 null。
  /// PC 桌面浏览器不支持 capture，会退化为文件选择器；手机浏览器仍可调起相机。
  Future<XFile?> pickFromCamera(BuildContext context) =>
      _cameraPicker.pickImage(source: ImageSource.camera);
}
