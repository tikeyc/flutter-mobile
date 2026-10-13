import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 好物商城（占位页）。
class MallPage extends StatelessWidget {
  const MallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(title: const Text('好物商城')),
      body: Center(
        child: Text(
          '好物商城建设中，敬请期待',
          style: AppTextStyles.body14.copyWith(color: AppColors.text3),
        ),
      ),
    );
  }
}
