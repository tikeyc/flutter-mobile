import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 内容详情页（占位）：从首页瀑布流卡片进入，bizId 供后续加载详情用。
class FeedDetailPage extends StatelessWidget {
  const FeedDetailPage({super.key, required this.bizId});

  final String bizId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(title: const Text('详情')),
      body: Center(
        child: Text(
          '内容详情建设中，敬请期待',
          style: AppTextStyles.body14.copyWith(color: AppColors.text3),
        ),
      ),
    );
  }
}
