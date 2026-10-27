import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/editor/data/sam_segmenter.dart';

void main() {
  test('web 端模型地址需带 Flutter 资源前缀', () {
    expect(
      samModelPath(isWeb: true),
      'assets/assets/onnx/model/sam_onnx_quantized_example.onnx',
    );
    expect(samModelPath(isWeb: false), kSamModelAsset);
  });
}
