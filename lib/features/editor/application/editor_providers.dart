import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// 修图工具。智能点选/自动抠图为占位工具，画布交互暂时禁用。
enum EditorTool { brush, smartSelect, autoCutout, eraser }

/// 编辑器状态。
class EditorState {
  const EditorState({this.imagePath, this.currentTool = EditorTool.brush});

  /// 当前编辑图片的本地文件路径；null 表示尚未选择。
  final String? imagePath;
  final EditorTool currentTool;

  EditorState copyWith({String? imagePath, EditorTool? currentTool}) {
    return EditorState(
      imagePath: imagePath ?? this.imagePath,
      currentTool: currentTool ?? this.currentTool,
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

  void setImage(String path) => state = state.copyWith(imagePath: path);

  /// 删除当前图片，工具选择保留。
  void clearImage() => state = EditorState(currentTool: state.currentTool);

  void selectTool(EditorTool tool) => state = state.copyWith(currentTool: tool);
}

/// 选图服务实例；页面经此触发相册/拍照，抽成 Provider 便于测试替换。
final imagePickServiceProvider = Provider<ImagePickService>(
  (ref) => ImagePickService(),
);

/// 选图服务：相册走 wechat_assets_picker（微信风格应用内相册），
/// 拍照走 image_picker（系统相机，最稳）。
class ImagePickService {
  final ImagePicker _cameraPicker = ImagePicker();

  /// 从相册选一张图，返回本地文件路径；用户取消返回 null。
  Future<String?> pickFromGallery(BuildContext context) async {
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.image,
      ),
    );
    if (assets == null || assets.isEmpty) return null;
    final file = await assets.first.file;
    return file?.path;
  }

  /// 拍照，返回照片文件路径；用户取消返回 null。
  Future<String?> pickFromCamera(BuildContext context) async {
    final XFile? photo = await _cameraPicker.pickImage(
      source: ImageSource.camera,
    );
    return photo?.path;
  }
}
