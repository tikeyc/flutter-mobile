import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 需求大厅（占位页）。
class DemandHallPage extends StatelessWidget {
  const DemandHallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(title: const Text('需求大厅')),
      body: Center(
        child: Text(
          '需求大厅建设中，敬请期待',
          style: AppTextStyles.body14.copyWith(color: AppColors.text3),
        ),
      ),
    );
  }
}
