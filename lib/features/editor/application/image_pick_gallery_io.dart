import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// 原生相册：微信风格应用内相册。
/// wechat_assets_picker / photo_manager 依赖 dart:io，只能经条件导入在原生端编译。
Future<XFile?> pickGalleryImage(BuildContext context) async {
  final List<AssetEntity>? assets = await AssetPicker.pickAssets(
    context,
    pickerConfig: const AssetPickerConfig(
      maxAssets: 1,
      requestType: RequestType.image,
    ),
  );
  if (assets == null || assets.isEmpty) return null;
  final file = await assets.first.file;
  return file == null ? null : XFile(file.path);
}
