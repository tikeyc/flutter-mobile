import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/auth/application/auth_providers.dart';
import 'package:intuly/features/auth/presentation/slide_captcha/slide_captcha_dialog.dart';

import 'fake_auth_repository.dart';
import 'in_memory_session_storage.dart';

/// 表单/页面测试宿主：注入假仓库、内存存储和假滑块。
class AuthTestHost {
  final repo = FakeAuthRepository();
  final storage = InMemorySessionStorage();
  final List<String> verifyUsers = [];

  /// 假滑块返回值；null 表示用户关闭了滑块。
  String? verifyResult = 'slide-ok';

  /// scroll: true 用于单个表单（套 Scaffold + 滚动）；整页自带 Scaffold 时传 false。
  Future<void> pump(WidgetTester tester, Widget child, {bool scroll = true}) {
    return tester.pumpWidget(ProviderScope(
      overrides: [
        authRepoProvider.overrideWithValue(repo),
        sessionStorageProvider.overrideWithValue(storage),
        slideVerifierProvider.overrideWithValue((context, user) async {
          verifyUsers.add(user);
          return verifyResult;
        }),
      ],
      child: MaterialApp(
        home: scroll
            ? Scaffold(
                body: SingleChildScrollView(padding: const EdgeInsets.all(32), child: child),
              )
            : child,
      ),
    ));
  }

  ProviderContainer container(WidgetTester tester, Finder within) =>
      ProviderScope.containerOf(tester.element(within));
}

/// 持有"已同意协议"状态，用于单独测表单。
class AgreedHolder extends StatefulWidget {
  const AgreedHolder({super.key, required this.builder, this.initial = true});

  final Widget Function(bool agreed, ValueChanged<bool> onChanged) builder;
  final bool initial;

  @override
  State<AgreedHolder> createState() => _AgreedHolderState();
}

class _AgreedHolderState extends State<AgreedHolder> {
  late bool _agreed = widget.initial;

  @override
  Widget build(BuildContext context) =>
      widget.builder(_agreed, (v) => setState(() => _agreed = v));
}

/// 等异步回调完成并让 SnackBar/Dialog 动画走完，但不跑满倒计时。
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
