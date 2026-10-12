import 'dart:convert';
import 'dart:typed_data';

/// `/login/ai/slide` 返回的拼图数据。所有尺寸都是原图像素。
class SlideChallenge {
  final String captchaId;
  final Uint8List backgroundBytes;
  final Uint8List pieceBytes;
  final double width;
  final double height;
  final double pieceWidth;
  final double pieceHeight;
  final double pieceTop; // pos.height：拼图块的纵向位置

  const SlideChallenge({
    required this.captchaId,
    required this.backgroundBytes,
    required this.pieceBytes,
    required this.width,
    required this.height,
    required this.pieceWidth,
    required this.pieceHeight,
    required this.pieceTop,
  });

  factory SlideChallenge.fromJson(Map<String, dynamic> json) {
    final id = json['imgCaptchaId'] as String?;
    final image = json['image'] as String?;
    final slide = json['slide'] as String?;
    final width = (json['width'] as num?)?.toDouble();
    final height = (json['height'] as num?)?.toDouble();
    if (id == null ||
        id.isEmpty ||
        image == null ||
        slide == null ||
        width == null ||
        width <= 0 ||
        height == null ||
        height <= 0) {
      throw const FormatException('滑块数据不完整');
    }
    final pos = json['pos'] as Map<String, dynamic>?;
    return SlideChallenge(
      captchaId: id,
      backgroundBytes: decodeBase64Image(image),
      pieceBytes: decodeBase64Image(slide),
      width: width,
      height: height,
      pieceWidth: (json['slideWidth'] as num?)?.toDouble() ?? 0,
      pieceHeight: (json['slideHeight'] as num?)?.toDouble() ?? 0,
      pieceTop: (pos?['height'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 兼容 `data:image/png;base64,xxx` 和纯 base64 两种格式。
Uint8List decodeBase64Image(String value) {
  final comma = value.indexOf(',');
  final raw = value.startsWith('data:') && comma >= 0
      ? value.substring(comma + 1)
      : value;
  return base64Decode(raw.trim());
}

/// `/login/ai/checkSlide` 的结果。
class SlideCheckResult {
  final bool passed;
  final String? loginSlide;
  final int errorCount;

  const SlideCheckResult({
    required this.passed,
    this.loginSlide,
    this.errorCount = 0,
  });
}
