/// 分割模型输出的原始 mask（`> 0` 为选中），与图片尺寸对应。
class MaskData {
  const MaskData({
    required this.values,
    required this.width,
    required this.height,
  });

  final List<num> values;
  final int width;
  final int height;
}
