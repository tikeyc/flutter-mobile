import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:npy/npy.dart';

/// npy 中的 float32 数组，按 C 序展平。
class NpyFloat32 {
  const NpyFloat32({required this.shape, required this.data});

  final List<int> shape;
  final Float32List data;
}

/// 用 [NpyParser] 解析 .npy 字节，仅接受 float32。
NpyFloat32 parseNpyFloat32(Uint8List bytes) {
  final parser = NpyParser<double>()
    ..checkMagicString(bytes)
    ..getVersion(bytes)
    ..getHeaderSize(bytes)
    ..getHeader(bytes)
    ..buildHeaderSection();

  final section = parser.headerSection;
  if (section == null) {
    throw const NpyParseException('npy header 不完整');
  }
  final dtype = section.header.dtype;
  if (dtype.type != NpyType.float || dtype.itemSize != 4) {
    throw NpyParseException('仅支持 float32，实际 dtype 为 $dtype');
  }

  parser.getData(bytes);
  if (!parser.isCompleted) {
    throw const NpyParseException('npy 数据不完整');
  }

  return NpyFloat32(
    shape: List<int>.unmodifiable(section.header.shape),
    data: Float32List.fromList(flattenCOrder<double>(parser.data)),
  );
}

Future<NpyFloat32> loadNpyFloat32Asset(String assetKey) async {
  final data = await rootBundle.load(assetKey);
  return parseNpyFloat32(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}
