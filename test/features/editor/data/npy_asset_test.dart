import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/editor/data/npy_asset.dart';
import 'package:npy/npy.dart';

Uint8List npyFixture(List nested, {NpyDType? dtype}) {
  final array = NdArray<double>.fromList(
    nested,
    dtype: dtype ?? NpyDType.float32(endian: NpyEndian.little),
  );
  return Uint8List.fromList(array.asBytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('解析内置 embedding 资源为 (1,256,64,64) float32', () async {
    final npy = await loadNpyFloat32Asset(
      'assets/onnx/IntelligenSelection.npy',
    );

    expect(npy.shape, [1, 256, 64, 64]);
    expect(npy.data, hasLength(256 * 64 * 64));
    expect(npy.data[0].isFinite, isTrue);
    expect(npy.data[12345].isFinite, isTrue);
  });

  test('解析 float32 npy 字节并按行优先展平', () {
    final bytes = npyFixture([
      [1.0, 2.0, 3.0],
      [4.0, 5.0, 6.0],
    ]);

    final npy = parseNpyFloat32(bytes);

    expect(npy.shape, [2, 3]);
    expect(npy.data, [1, 2, 3, 4, 5, 6]);
  });

  test('非 float32 dtype 抛 NpyParseException', () {
    final array = NdArray<int>.fromList(
      [1, 2, 3],
      dtype: NpyDType.int32(endian: NpyEndian.little),
    );

    expect(
      () => parseNpyFloat32(Uint8List.fromList(array.asBytes)),
      throwsA(isA<NpyParseException>()),
    );
  });

  test('魔数错误抛 NpyParseException', () {
    final bytes = npyFixture([1.0, 2.0]);
    bytes[0] = 0;

    expect(() => parseNpyFloat32(bytes), throwsA(isA<NpyParseException>()));
  });
}
