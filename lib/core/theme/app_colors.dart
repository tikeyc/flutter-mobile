import 'package:flutter/painting.dart';

/// 设计稿颜色 token（注释为 MasterGo token 名）。
class AppColors {
  AppColors._();

  static const Color bg1 = Color(0xFFFFFFFF); // 中性色 neutral/背景/color-bg-1
  static const Color bg2 = Color(0xFFF9F9FA); // 中性色 neutral/背景/color-bg-2
  static const Color border3 = Color(0xFFE5E6EB); // 中性色 neutral/描边/color-border-3
  static const Color border4 = Color(0xFFF2F3F5); // 中性色 neutral/描边/color-border-4
  static const Color text1 = Color(0xFF1D2129); // 中性色 neutral/文字&图标/color-text-1
  static const Color text2 = Color(0xFF4D5562); // 中性色 neutral/文字&图标/color-text-2
  static const Color text3 = Color(0xFF868F9C); // 中性色 neutral/文字&图标/color-text-3
  static const Color text4 = Color(0xFFCACCD0); // 中性色 neutral/文字&图标/color-text-4
  static const Color textWhite = Color(0xFFFFFFFF); // 中性色 neutral/文字&图标/color-text-5
  static const Color primary = Color(0xFF0057FF); // 主色 primary/primary-base
  static const Color mask2 = Color(0x99000000); // 特殊色 special/mask-2
  static const Color sliderTrack = Color(0xFFDEDFE0); // Light/辅助色 Auxiliary/Info/Info-7
  // 设计稿未给出错误色，取常用红色作为近似值。
  static const Color danger = Color(0xFFF53F3F);
}
