import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_text_styles.dart';
import '../auth/application/auth_providers.dart';

/// token 脱敏：超过 10 位时只显示前 10 位。
String maskToken(String token) =>
    token.length > 10 ? '${token.substring(0, 10)}…' : '••••••';

/// 首页占位：显示登录账号、脱敏 token、退出登录。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('首页')),
      body: Center(
        child: session == null
            ? const SizedBox.shrink()
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Text(session.account, style: AppTextStyles.title16),
                const SizedBox(height: 8),
                Text('Token: ${maskToken(session.token)}', style: AppTextStyles.body12),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => ref.read(authProvider.notifier).signOut(),
                  child: const Text('退出登录'),
                ),
              ]),
      ),
    );
  }
}
