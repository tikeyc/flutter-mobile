import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

/// Web 相册：打开浏览器文件选择器，返回的 XFile 以 blob URL 作为 path。
Future<XFile?> pickGalleryImage(BuildContext context) {
  return ImagePicker().pickImage(source: ImageSource.gallery);
}
