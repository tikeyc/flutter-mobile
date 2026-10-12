import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import 'widgets/account_login_form.dart';
import 'widgets/phone_login_form.dart';

enum LoginMode { phone, account }

/// 登录页：顶部"登录/注册"，文字 Tab 切换手机号 / 账号登录，协议勾选状态跨 Tab 共享。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  LoginMode _mode = LoginMode.phone;
  bool _agreed = false;

  void _setAgreed(bool v) => setState(() => _agreed = v);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录/注册'),
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: SvgPicture.asset(AppIcons.close, width: 24, height: 24),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ModeTabs(mode: _mode, onChanged: (m) => setState(() => _mode = m)),
              const SizedBox(height: 8),
              IndexedStack(
                index: _mode.index,
                children: [
                  PhoneLoginForm(agreed: _agreed, onAgreedChanged: _setAgreed),
                  AccountLoginForm(agreed: _agreed, onAgreedChanged: _setAgreed),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onChanged});

  final LoginMode mode;
  final ValueChanged<LoginMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(LoginMode m, String label) {
      final selected = m == mode;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(m),
          child: Text(
            label,
            style: selected
                ? AppTextStyles.title14
                : AppTextStyles.body14.copyWith(color: AppColors.text3),
          ),
        ),
      );
    }

    return Row(children: [
      tab(LoginMode.phone, '手机号登录'),
      const SizedBox(width: 24),
      tab(LoginMode.account, '账号登录'),
    ]);
  }
}
