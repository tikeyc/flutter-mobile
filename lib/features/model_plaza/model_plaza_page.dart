import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 模型广场（占位页）。
class ModelPlazaPage extends StatelessWidget {
  const ModelPlazaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(title: const Text('模型广场')),
      body: Center(
        child: Text(
          '模型广场建设中，敬请期待',
          style: AppTextStyles.body14.copyWith(color: AppColors.text3),
        ),
      ),
    );
  }
}
