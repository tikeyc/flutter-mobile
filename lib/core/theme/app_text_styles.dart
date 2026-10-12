import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// 设计稿字体 token。height = lineHeight / fontSize。
class AppTextStyles {
  AppTextStyles._();

  // 标题/title-16-CN
  static const TextStyle title16 = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 24 / 16,
      color: AppColors.text1);
  // 标题/title-14-CN
  static const TextStyle title14 = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 20 / 14,
      color: AppColors.text1);
  // 正文/body-14-CN
  static const TextStyle body14 = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
      color: AppColors.text1);
  // 正文/body-12-CN
  static const TextStyle body12 = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 16 / 12,
      color: AppColors.text2);
  // 正文/body-16-CN
  static const TextStyle body16 = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 24 / 16,
      color: AppColors.text1);
}
